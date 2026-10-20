import os
import sys
import pandas as pd
import matplotlib.pyplot as plt

# Đảm bảo encoding
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

base_dir = os.path.dirname(os.path.abspath(__file__))
plots_dir = os.path.join(base_dir, "plots")
csv_path = os.path.join(base_dir, "outputs", "analysis", "comparison_table_fair_avg.csv")
os.makedirs(plots_dir, exist_ok=True)

if not os.path.exists(csv_path):
    print(f"❌ Không tìm thấy file: {csv_path}")
    sys.exit(1)

df = pd.read_csv(csv_path)

# Chuẩn bị dữ liệu bảng
table_data = [
    ["Kịch bản", "Chỉ số", "Baseline (Đếm xe)", "Proposed (CAO)", "Cải thiện (%)", "p-value", "Ý nghĩa (p < 0.05)"]
]

prev_scen = None
for _, row in df.iterrows():
    scen = row["Scenario"]
    scen_display = scen if scen != prev_scen else ""
    prev_scen = scen
    
    val_imp = f"+{row['Cải thiện Area vs Fair Paper (%)']}%" if float(row['Cải thiện Area vs Fair Paper (%)']) >= 0 else f"{row['Cải thiện Area vs Fair Paper (%)']}%"
    p_val_str = f"{row['p-value (Area vs Fair Paper)']:.4f}" if isinstance(row['p-value (Area vs Fair Paper)'], (int, float)) else str(row['p-value (Area vs Fair Paper)'])
    sig_str = "Có *" if "Có" in str(row['Ý nghĩa (p<0.05)']) else "Không"
    
    table_data.append([
        scen_display,
        row["Chỉ số"],
        row["CBMP Fair Paper (mean ± std)"],
        row["CBMP Area (mean ± std)"],
        val_imp,
        p_val_str,
        sig_str
    ])

fig, ax = plt.subplots(figsize=(11.5, 6.2), dpi=300)
ax.axis('tight')
ax.axis('off')

table = ax.table(
    cellText=table_data[1:],
    colLabels=table_data[0],
    loc='center',
    cellLoc='center'
)

table.auto_set_font_size(False)
table.set_fontsize(9.5)
table.scale(1.0, 1.8)

# Style
header_color = '#1f4e79'
row_colors = ['#f2f5f9', '#ffffff']

current_scen_idx = 0
prev_s = ""
for (row, col), cell in table.get_celld().items():
    cell.set_edgecolor('#d9d9d9')
    cell.set_linewidth(0.8)
    if row == 0:
        cell.set_text_props(weight='bold', color='white')
        cell.set_facecolor(header_color)
    else:
        # Nhóm màu theo kịch bản
        r_idx = row - 1
        scen_name = df.iloc[r_idx]["Scenario"]
        if scen_name == "Trung bình (3 kịch bản)":
            cell.set_facecolor('#e8f4f8')
            cell.set_text_props(weight='bold')
        else:
            scen_grp = r_idx // 3
            cell.set_facecolor(row_colors[scen_grp % 2])
            
        # Cột cải thiện và ý nghĩa
        if col == 4:
            val = cell.get_text().get_text()
            if '+' in val:
                cell.set_text_props(weight='bold', color='#1e7145')
        elif col == 6:
            val = cell.get_text().get_text()
            if 'Có' in val:
                cell.set_text_props(weight='bold', color='#1e7145')

plt.title("BẢNG SO SÁNH HIỆU NĂNG ĐIỀU KHIỂN (CBMP PAPER FAIR VS CBMP AREA - 10 SEEDS)", 
          fontsize=12, fontweight='bold', pad=15, color='#1f4e79')

out_path = os.path.join(plots_dir, "table_comparison_image.png")
plt.savefig(out_path, bbox_inches='tight', dpi=300)
plt.close()
print(f"✅ Đã xuất ảnh bảng so sánh: {out_path}")
