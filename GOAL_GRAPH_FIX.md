# 如何让 Goal Graph 不为空

## 问题分析

从运行日志看，Goal Graph **不是真的空**，而是质量不稳定：

### Episode 0（chair）- 图太简单
```
LLM object extraction: [chair]
LLM relation extraction: （返回了无关对象 Image, Material, Color）
结果：1个节点，0条边 → 无法有效导航
```

### Episode 1（toilet）- 正常
```
LLM object extraction: [toilet, sink, mirror, towel rack, tissue box]
LLM relation extraction: 4条有效关系
结果：5个节点，4条边 → 正常工作！
```

## 根本原因

**VLM 对图像的描述质量不稳定**，原 prompt 太简单：
```python
'Describe the object at the center of the image and indicate the spatial relationship between other objects and it.'
```
这导致 VLM 只描述中心物体，忽略周围环境。

## 解决方案

已优化 3 个关键部分：

### 1. VLM Prompt 优化（`src/graph/graph.py`）
```python
# 旧 prompt（太简单）
self.prompt_image2text = 'Describe the object at the center of the image...'

# 新 prompt（明确要求描述周围物体）
self.prompt_image2text = 'Describe the main object in the center of this image, including its color, material, and appearance. Then describe what other objects or furniture are visible around it and their spatial relationships (such as next to, on, under, behind, in front of). Be specific and mention at least 2-3 surrounding objects if visible.'
```

### 2. 对象提取 Prompt 优化（`src/graph/graphbuilder.py`）
```python
# 新 prompt 强调提取 ALL 对象
object_prompt = f"""Extract ALL objects and furniture mentioned in the following description. 
Include the main object and ANY surrounding objects, furniture, or items.
Output ONLY in this format: [object1, object2, object3, ...]

Description: {description}

Answer (list only):"""
```

### 3. 关系提取 Prompt 优化
```python
# 新 prompt 更明确格式要求
relation_prompt = f"""Given these objects: {', '.join(objects)}
From the description: {description}

List their spatial relationships in this EXACT format (one per line):
<Object A> and <Object B>: <Object A> is <relation> <Object B>

Only use these relations: next to, on, under, above, below, behind, in front of
Output (no extra text):"""
```

### 4. 调试输出增强

现在运行时会清晰显示：
```
============================================================
Building Goal Graph from: <VLM描述>
============================================================
LLM object extraction raw response:
[提取的对象列表]
Extracted 5 objects: ['chair', 'table', 'lamp', ...]

LLM relation extraction raw response:
Chair and Table: Chair is next to Table
...
Extracted 3 relations

>>> GOAL GRAPH BUILT <<<
  Nodes: 5 - ['chair', 'table', 'lamp', 'window', 'wall']
  Edges: 3 - [('chair', 'next to', 'table'), ...]
============================================================
```

## 测试运行

```bash
cd /home/liuyf/UniGoal/UniGoal
python main.py --goal_type ins-image
```

### 预期输出改进

**之前**：
```
episode:0, cat_id:0, cat_name:chair
LLM object extraction raw response:
[chair]
>>> GOAL GRAPH: 1 nodes, 0 edges  ← 太简单！
```

**现在**：
```
episode:0, cat_id:0, cat_name:chair
============================================================
Building Goal Graph from: A brown wooden chair is positioned in the center. 
To its left is a small side table with a lamp on top. Behind the chair is 
a large window with white curtains. The floor appears to be hardwood.
============================================================
LLM object extraction raw response:
[chair, table, lamp, window, curtains, floor]
Extracted 6 objects: ['chair', 'table', 'lamp', 'window', 'curtains', 'floor']

LLM relation extraction raw response:
Chair and Table: Chair is next to Table
Table and Lamp: Table is under Lamp
Chair and Window: Chair is in front of Window
Extracted 3 relations

>>> GOAL GRAPH BUILT <<<
  Nodes: 6 - ['chair', 'table', 'lamp', 'window', 'curtains', 'floor']
  Edges: 3 - [('chair', 'next to', 'table'), ('table', 'under', 'lamp'), ...]
============================================================
```

## 如果还是不够丰富

### 方案 A：调整 VLM prompt 更详细
在 `src/graph/graph.py` 第 232 行，进一步优化：
```python
self.prompt_image2text = '''Describe this image in detail:
1. Main object: What is the object in the center? (color, material, size)
2. Surrounding objects: What other furniture or objects are visible? (list at least 3-5)
3. Spatial layout: How are these objects positioned relative to each other? (next to, on, under, behind, etc.)
4. Room context: What room is this likely in? What else would typically be nearby?

Be specific and comprehensive.'''
```

### 方案 B：增加对象数量限制
在 `src/graph/graphbuilder.py` 第 51 行，改为提取更多对象：
```python
return candidates[:10]  # 从 5 改为 10
```

## 验证是否成功

运行后查看输出中的：
```
>>> GOAL GRAPH BUILT <<<
  Nodes: X - [列表]  ← 应该至少 3-5 个节点
  Edges: Y - [列表]  ← 应该至少 2-3 条边
```

如果还是只有 1 个节点，请检查：
1. LLM/VLM 服务是否正常（ollama 是否运行？）
2. VLM 的原始输出（"Building Goal Graph from:" 后面的文本是否足够详细？）
3. 如果 VLM 输出很简单，可能需要换用更强的模型（如 llama3.2-vision:90b）

## 快速测试

```bash
# 测试单个 episode
python main.py --goal_type ins-image --episode_id 0

# 或者测试 text 模式（更稳定）
python main.py --goal_type text --episode_id 0
```
