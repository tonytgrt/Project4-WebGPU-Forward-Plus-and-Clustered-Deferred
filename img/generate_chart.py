import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

# Read the CSV data
df = pd.read_csv('benchmark_rtx5080.csv')

# Create figure with subplots
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
fig.suptitle('WebGPU Rendering Performance Comparison - RTX 5080', fontsize=16, fontweight='bold')

# Color scheme
colors = {
    'naive': '#e74c3c',
    'forward+': '#3498db',
    'clustered deferred': '#2ecc71'
}

# Plot 1: Average Frame Time
for mode in df['Render Mode'].unique():
    mode_data = df[df['Render Mode'] == mode]
    ax1.plot(mode_data['Number of Lights'], mode_data['Average Frame Time (ms)'],
             marker='o', linewidth=2, markersize=6, label=mode.title(),
             color=colors[mode], alpha=0.9)

ax1.set_xlabel('Number of Lights', fontsize=12, fontweight='bold')
ax1.set_ylabel('Average Frame Time (ms)', fontsize=12, fontweight='bold')
ax1.set_title('Average Frame Time vs Number of Lights', fontsize=14, pad=10)
ax1.grid(True, alpha=0.3, linestyle='--')
ax1.legend(fontsize=11, loc='upper left')
ax1.set_xlim(400, 5100)
ax1.set_ylim(0, max(df['Average Frame Time (ms)']) * 1.1)

# Add FPS reference lines
fps_targets = [60, 30, 15]
fps_colors = ['green', 'orange', 'red']
for fps, color in zip(fps_targets, fps_colors):
    frame_time = 1000 / fps
    ax1.axhline(y=frame_time, color=color, linestyle=':', alpha=0.5, linewidth=1)
    ax1.text(5100, frame_time, f'{fps} FPS', verticalalignment='center',
             fontsize=9, color=color, weight='bold')

# Plot 2: Speedup Comparison (relative to Naive)
light_counts = df['Number of Lights'].unique()

forward_plus_speedup = []
clustered_deferred_speedup = []

for lights in light_counts:
    naive_time = df[(df['Render Mode'] == 'naive') & (df['Number of Lights'] == lights)]['Average Frame Time (ms)'].values[0]
    fp_time = df[(df['Render Mode'] == 'forward+') & (df['Number of Lights'] == lights)]['Average Frame Time (ms)'].values[0]
    cd_time = df[(df['Render Mode'] == 'clustered deferred') & (df['Number of Lights'] == lights)]['Average Frame Time (ms)'].values[0]

    forward_plus_speedup.append(naive_time / fp_time)
    clustered_deferred_speedup.append(naive_time / cd_time)

x_labels = [str(int(x)) for x in light_counts]
x_pos = list(range(len(light_counts)))

bar_width = 0.35
bar1 = ax2.bar([p - bar_width/2 for p in x_pos], forward_plus_speedup,
               width=bar_width, label='Forward+ vs Naive',
               color=colors['forward+'], alpha=0.8, edgecolor='black', linewidth=0.5)
bar2 = ax2.bar([p + bar_width/2 for p in x_pos], clustered_deferred_speedup,
               width=bar_width, label='Clustered Deferred vs Naive',
               color=colors['clustered deferred'], alpha=0.8, edgecolor='black', linewidth=0.5)

ax2.set_xlabel('Number of Lights', fontsize=12, fontweight='bold')
ax2.set_ylabel('Speedup Factor (x faster than Naive)', fontsize=12, fontweight='bold')
ax2.set_title('Performance Speedup Relative to Naive Renderer', fontsize=14, pad=10)
ax2.set_xticks(x_pos)
ax2.set_xticklabels(x_labels, rotation=0)
ax2.legend(fontsize=11, loc='upper left')
ax2.grid(True, alpha=0.3, linestyle='--', axis='y')
ax2.axhline(y=1, color='red', linestyle='-', alpha=0.3, linewidth=2)
ax2.set_ylim(0, max(max(forward_plus_speedup), max(clustered_deferred_speedup)) * 1.15)

# Add value labels on bars - stagger them to avoid overlap
for i, (fp, cd) in enumerate(zip(forward_plus_speedup, clustered_deferred_speedup)):
    #if i % 2 == 0:
        ax2.text(i - bar_width/2, fp + 0.5, f'{fp:.1f}x',
                ha='center', va='bottom', fontsize=9, weight='bold', color=colors['forward+'])

    #if i % 2 == 1 or i == len(clustered_deferred_speedup) - 1:
        ax2.text(i + bar_width/2, cd + 0.5, f'{cd:.1f}x',
                ha='center', va='bottom', fontsize=9, weight='bold', color=colors['clustered deferred'])

plt.tight_layout()
plt.savefig('performance_comparison.png', dpi=300, bbox_inches='tight')
print("Chart saved to performance_comparison.png")

# Create a second detailed chart showing min/max variance
fig2, ax3 = plt.subplots(1, 1, figsize=(12, 6))
fig2.suptitle('Frame Time Variance Analysis - RTX 5080', fontsize=16, fontweight='bold')

x_offset = {'naive': -200, 'forward+': 0, 'clustered deferred': 200}

for mode in df['Render Mode'].unique():
    mode_data = df[df['Render Mode'] == mode]
    x_positions = mode_data['Number of Lights'] + x_offset[mode]

    # Plot average as line
    ax3.plot(x_positions, mode_data['Average Frame Time (ms)'],
            marker='o', linewidth=2, markersize=6, label=f'{mode.title()} (Avg)',
            color=colors[mode], alpha=0.9)

    # Plot min/max as shaded area
    ax3.fill_between(x_positions,
                     mode_data['Min Frame Time (ms)'],
                     mode_data['Max Frame Time (ms)'],
                     alpha=0.15, color=colors[mode])

    # Add error bars
    ax3.errorbar(x_positions, mode_data['Average Frame Time (ms)'],
                yerr=[mode_data['Average Frame Time (ms)'] - mode_data['Min Frame Time (ms)'],
                      mode_data['Max Frame Time (ms)'] - mode_data['Average Frame Time (ms)']],
                fmt='none', ecolor=colors[mode], alpha=0.3, capsize=3)

ax3.set_xlabel('Number of Lights', fontsize=12, fontweight='bold')
ax3.set_ylabel('Frame Time (ms)', fontsize=12, fontweight='bold')
ax3.set_title('Frame Time with Min/Max Variance (Shaded Regions Show Range)', fontsize=14, pad=10)
ax3.grid(True, alpha=0.3, linestyle='--')
ax3.legend(fontsize=10, loc='upper left')
ax3.set_xlim(400, 5100)

plt.tight_layout()
plt.savefig('performance_variance.png', dpi=300, bbox_inches='tight')
print("Variance chart saved to performance_variance.png")

# Print summary statistics
print("\n=== Performance Summary ===")
print(f"\nAt 5000 lights:")
for mode in ['naive', 'forward+', 'clustered deferred']:
    data = df[(df['Render Mode'] == mode) & (df['Number of Lights'] == 5000)].iloc[0]
    print(f"{mode.title():20s}: {data['Average Frame Time (ms)']:6.1f}ms avg, "
          f"{data['Min Frame Time (ms)']:6.1f}ms min, {data['Max Frame Time (ms)']:6.1f}ms max")

print(f"\nSpeedup at 5000 lights:")
naive_5000 = df[(df['Render Mode'] == 'naive') & (df['Number of Lights'] == 5000)]['Average Frame Time (ms)'].values[0]
fp_5000 = df[(df['Render Mode'] == 'forward+') & (df['Number of Lights'] == 5000)]['Average Frame Time (ms)'].values[0]
cd_5000 = df[(df['Render Mode'] == 'clustered deferred') & (df['Number of Lights'] == 5000)]['Average Frame Time (ms)'].values[0]

print(f"Forward+ vs Naive:           {naive_5000/fp_5000:.1f}x faster")
print(f"Clustered Deferred vs Naive: {naive_5000/cd_5000:.1f}x faster")
print(f"Clustered Deferred vs Forward+: {fp_5000/cd_5000:.1f}x faster")
