class GraphBuilder:
    def __init__(self, llm=None):
        self.llm = llm

    def get_objects(self, llm_response):
        # Try several strategies to robustly extract a list of objects from LLM response
        import re

        if not isinstance(llm_response, str):
            return []

        # 1) Try to find content inside square brackets: [a, b, c]
        m = re.search(r"\[([^\]]+)\]", llm_response)
        if m:
            items = [s.strip() for s in m.group(1).split(',') if s.strip()]
            return items[:5]

        # 2) Try to find a line that looks like a comma-separated list
        for line in llm_response.split('\n'):
            if ',' in line and len(line.split(',')) > 1:
                items = [s.strip() for s in line.split(',') if s.strip()]
                if len(items) > 0:
                    return items[:5]

        # 3) Try to extract words after keywords like "Objects:" or "Items:"
        m2 = re.search(r"(?:Objects|Items|objects|items)[:\-]\s*(.*)", llm_response)
        if m2:
            items = [s.strip() for s in re.split(r",|;", m2.group(1)) if s.strip()]
            if len(items) > 0:
                return items[:5]

        # 4) Fallback: extract probable noun-like tokens (letters and spaces), filter stopwords
        tokens = re.findall(r"[A-Za-z ]{3,}", llm_response)
        stopwords = set(["the", "a", "an", "and", "or", "is", "are", "in", "on", "with", "of"])
        candidates = []
        for t in tokens:
            t = t.strip()
            # skip short or stopword tokens
            if len(t) < 3:
                continue
            parts = [p.strip() for p in re.split(r"and|,|;", t) if p.strip()]
            for p in parts:
                p_low = p.lower()
                if p_low in stopwords:
                    continue
                if p not in candidates:
                    candidates.append(p)
                if len(candidates) >= 5:
                    break
            if len(candidates) >= 5:
                break

        return candidates[:5]

    def get_relations(self, llm_response, objects):
        """Extract relations with case-insensitive object matching and clean relation types"""
        relations = []
        
        # Create a mapping from lowercase to original object names
        object_map = {obj.lower(): obj for obj in objects}
        
        # Standard spatial relations to look for
        spatial_relations = ['next to', 'on', 'under', 'above', 'below', 'behind', 
                            'in front of', 'in', 'near', 'beside', 'opposite to']
        
        for line in llm_response.split('\n'):
            line = line.strip()
            if not line:
                continue
                
            relation = {'source': '', 'target': '', 'type': ''}
            parts = line.split(': ')
            if len(parts) == 2:
                relation_info = parts[1].strip()
                relation_parts = relation_info.split(' is ')
                if len(relation_parts) == 2:
                    source_target = parts[0].strip().split(' and ')
                    if len(source_target) == 2:
                        source_raw = source_target[0].strip()
                        target_raw = source_target[1].strip()
                        relation_raw = relation_parts[1].strip()
                        
                        # Case-insensitive matching for objects
                        source_lower = source_raw.lower()
                        target_lower = target_raw.lower()
                        
                        if source_lower in object_map and target_lower in object_map:
                            # Extract clean relation type (remove object name from relation)
                            relation_type = relation_raw
                            for spatial_rel in spatial_relations:
                                if spatial_rel in relation_raw.lower():
                                    relation_type = spatial_rel
                                    break
                            
                            relation = {
                                'source': object_map[source_lower], 
                                'target': object_map[target_lower], 
                                'type': relation_type
                            }
                            relations.append(relation)
        return relations

    def parse_text_description(self, description):
        object_prompt = f"""Extract ALL objects and furniture mentioned in the following description. 
Include the main object and ANY surrounding objects, furniture, or items.
Output ONLY in this format: [object1, object2, object3, ...]

Description: {description}

Answer (list only):"""
        if self.llm is None:
            object_response = ''
        else:
            object_response = self.llm(object_prompt)
        # Print raw LLM response to help debugging when goal graph is empty
        try:
            print('LLM object extraction raw response:')
            print(object_response)
        except:
            pass
        try:
            objects = self.get_objects(object_response)
            print(f'Extracted {len(objects)} objects: {objects}')
        except Exception as e:
            print(f'Object extraction failed: {e}')
            objects = []

        if len(objects) == 0:
            print('WARNING: No objects extracted from description!')
            return [], []

        relation_prompt = f"""Given these objects: {', '.join(objects)}
From the description: {description}

List their spatial relationships in this EXACT format (one per line):
<Object A> and <Object B>: <Object A> is <relation> <Object B>

Only use these relations: next to, on, under, above, below, behind, in front of
Output (no extra text):"""
        
        if self.llm is None:
            relation_response = ''
        else:
            relation_response = self.llm(relation_prompt)
        try:
            print('LLM relation extraction raw response:')
            print(relation_response)
        except:
            pass
        relations = self.get_relations(relation_response, objects)
        print(f'Extracted {len(relations)} relations')

        return objects, relations

        return objects, relations

    def build_graph(self, objects, relations):
        graph = {
            'nodes': [{'id': obj} for obj in objects],
            'edges': [{'source': r['source'], 'target': r['target'], 'type': r['type']} for r in relations]
        }
        return graph

    def build_graph_from_text(self, text_goal):
        objects, relations = self.parse_text_description(text_goal)
        graph = self.build_graph(objects, relations)
        return graph
