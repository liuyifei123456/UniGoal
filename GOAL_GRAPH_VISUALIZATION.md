# Goal Graph 可视化修复说明

## 问题

在可视化界面中，左下角的 "Goal Graph" 区域一直是空白的。

## 原因

原代码中虽然定义了 "Goal Graph" 标题，但**从未绘制实际的 goal graph 内容**到这个区域（位置：`vis_image[315:530, 25:240]`）。

## 修复内容

### 1. 让 Agent 持有 Graph 引用

**文件**: `main.py`
```python
# 第 84 行，添加
agent.set_graph(graph)  # Pass graph to agent for visualization
```

### 2. 添加 set_graph 方法

**文件**: `src/agent/unigoal/agent.py`
```python
def set_graph(self, graph):
    """Set graph object for visualization"""
    self.graph = graph
```

### 3. 添加 Goal Graph 绘制方法

**文件**: `src/agent/unigoal/agent.py`
```python
def _draw_goal_graph(self):
    """Draw goal graph as a simple text representation"""
    try:
        goalgraph = self.graph.goalgraph
        if not goalgraph or len(goalgraph.get('nodes', [])) == 0:
            return None
        
        # Create white canvas
        canvas = np.ones((215, 215, 3), dtype=np.uint8) * 255
        
        # Extract nodes and edges
        nodes = goalgraph.get('nodes', [])
        edges = goalgraph.get('edges', [])
        
        # Create text representation
        graph_text = []
        graph_text.append("Nodes:")
        for i, node in enumerate(nodes[:5]):  # Max 5 nodes
            node_id = node.get('id', f'node{i}')
            graph_text.append(f"  {node_id}")
        
        if len(edges) > 0:
            graph_text.append("")
            graph_text.append("Edges:")
            for i, edge in enumerate(edges[:5]):  # Max 5 edges
                src = edge.get('source', '?')
                tgt = edge.get('target', '?')
                rel = edge.get('type', 'related to')
                # Shorten long relation names
                if len(rel) > 15:
                    rel = rel[:12] + '...'
                graph_text.append(f"  {src}->{tgt}")
                graph_text.append(f"    [{rel}]")
        
        # Draw text on canvas
        add_text_list(canvas, graph_text[:14], position=(5, 15), font_scale=0.4, thickness=1)
        
        return canvas
    except Exception as e:
        print(f"Failed to draw goal graph: {e}")
        return None
```

### 4. 在可视化时调用绘制方法

**文件**: `src/agent/unigoal/agent.py` 的 `visualize()` 方法
```python
# 在绘制 Goal 图像/文本后添加
# Draw Goal Graph visualization
if self.args.environment == 'habitat' and self.graph is not None and hasattr(self.graph, 'goalgraph'):
    goal_graph_vis = self._draw_goal_graph()
    if goal_graph_vis is not None:
        vis_image[315:530, 25:240] = goal_graph_vis
```

## 预期效果

运行 `python main.py --goal_type ins-image` 后，可视化界面的左下角 "Goal Graph" 区域将显示：

```
Nodes:
  chair
  table
  lamp

Edges:
  chair->table
    [next to]
  table->lamp
    [on]
```

## 示例输出格式

### 简单场景（单个对象）
```
Nodes:
  chair
```

### 复杂场景（多个对象和关系）
```
Nodes:
  toilet
  sink
  mirror
  towel rack
  tissue box

Edges:
  toilet->sink
    [next to]
  toilet->mirror
    [next to]
  toilet->towel rack
    [next to]
```

## 测试

运行以下命令测试可视化：

```bash
cd /home/liuyf/UniGoal/UniGoal
python main.py --goal_type ins-image --episode_id 0
```

查看生成的视频：
```bash
ls outputs/experiments/experiment_0/visualization/videos/
```

或查看实时截图：
```bash
ls outputs/tmp/v.jpg
```

## 注意事项

1. **Goal Graph 必须先生成**：只有在 `graph.set_image_goal()` 或 `graph.set_text_goal()` 被调用后，goal graph 才会存在
2. **空 Graph 不显示**：如果 goal graph 为空（0 nodes），该区域保持空白
3. **文本截断**：最多显示 5 个节点和 5 条边，避免文字溢出
4. **字体大小**：使用 `font_scale=0.4` 以适应 215x215 的小区域

## 调试

如果 Goal Graph 仍然不显示，检查：

1. **Graph 对象是否传递**：
   ```python
   print(f"Agent has graph: {agent.graph is not None}")
   ```

2. **Goal Graph 是否生成**：
   ```python
   if hasattr(agent.graph, 'goalgraph'):
       print(f"Goal graph nodes: {len(agent.graph.goalgraph['nodes'])}")
       print(f"Goal graph edges: {len(agent.graph.goalgraph['edges'])}")
   ```

3. **可视化是否启用**：
   ```bash
   # 确保 config 中 visualize: 1
   cat configs/config_habitat.yaml | grep visualize
   ```

## 后续改进建议

如果想要更美观的可视化，可以考虑：

1. **使用 NetworkX + Matplotlib** 绘制真正的图形结构
2. **节点用圆圈表示**，边用箭头连接
3. **颜色编码**：不同类型的关系用不同颜色
4. **布局算法**：使用 spring layout 或 hierarchical layout

示例代码（高级版本）：
```python
import networkx as nx
import matplotlib.pyplot as plt
from matplotlib.backends.backend_agg import FigureCanvasAgg

def _draw_goal_graph_advanced(self):
    G = nx.DiGraph()
    for node in nodes:
        G.add_node(node['id'])
    for edge in edges:
        G.add_edge(edge['source'], edge['target'], label=edge['type'])
    
    fig, ax = plt.subplots(figsize=(2.15, 2.15), dpi=100)
    pos = nx.spring_layout(G)
    nx.draw(G, pos, ax=ax, with_labels=True, node_color='lightblue', 
            node_size=500, font_size=6, arrows=True)
    
    canvas = FigureCanvasAgg(fig)
    canvas.draw()
    img = np.frombuffer(canvas.tostring_rgb(), dtype='uint8')
    img = img.reshape(215, 215, 3)
    plt.close(fig)
    return img
```
