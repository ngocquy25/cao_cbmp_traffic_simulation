import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import os
import glob
import re

# Đảm bảo stdout sử dụng encoding utf-8 trên Windows
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

# Thư mục chứa dữ liệu và lưu biểu đồ
base_dir = os.path.dirname(os.path.abspath(__file__))
outputs_dir = os.path.join(base_dir, "outputs")
plots_dir = os.path.join(base_dir, "plots")
os.makedirs(plots_dir, exist_ok=True)

def load_gama_csv(filepath):
    """
    Hàm đọc file CSV từ GAMA và bỏ qua dòng tiêu đề có chứa nháy đơn đầu tiên nếu có.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        first_line = f.readline().strip()
    
    if (first_line.startswith("'") and first_line.endswith("'")) or (first_line.startswith('"') and first_line.endswith('"')):
        df = pd.read_csv(filepath, skiprows=1)
    else:
        df = pd.read_csv(filepath)
        
    df.columns = [c.strip() for c in df.columns]
    return df

# 1. Quét tìm các file KPI_Result_*.csv
kpi_files = glob.glob(os.path.join(outputs_dir, "KPI_Result_*.csv"))

# Regex để phân tích tên file
pattern = re.compile(r"KPI_Result_([A-Za-z0-9_]+)_([A-Za-z0-9]+_\d+)_rep(\d+)\.csv")

data_records = []

for file_path in kpi_files:
    file_name = os.path.basename(file_path)
    match = pattern.match(file_name)
    if not match:
        continue
        
    algo, scenario, rep = match.groups()
    rep = int(rep)
    
    try:
        df_file = load_gama_csv(file_path)
        if df_file.empty:
            continue
            
        # Gom nhóm theo Cycle để lấy giá trị trung bình trên toàn mạng lưới tại mỗi chu kỳ của lần chạy này
        df_cycle = df_file.groupby('Cycle').agg({
            'Queue_Length': 'mean',
            'Throughput_per_Cycle': 'sum',
            'Average_Delay': 'mean'
        }).reset_index()
        
        df_cycle['Algorithm'] = algo
        df_cycle['Scenario'] = scenario
        df_cycle['Replicate'] = rep
        
        data_records.append(df_cycle)
    except Exception as e:
        print(f"⚠️ Cannot read file {file_name}: {e}")

if not data_records:
    print("❌ ERROR: No valid KPI data found to plot!")
    print("Please make sure the KPI files in the outputs directory are named like: KPI_Result_<Algorithm>_<Scenario>_rep<ID>.csv")
    sys.exit(1)

# Gộp tất cả dữ liệu
df_all = pd.concat(data_records, ignore_index=True)

# Loại bỏ chu kỳ chưa hoàn tất ở cuối mô phỏng (chu kỳ 60 chỉ chạy vài ms khi hết giờ 7200s)
df_all = df_all[(df_all['Cycle'] >= 1) & (df_all['Cycle'] <= 59)]

# Lấy danh sách các Kịch bản (Scenario) và Thuật toán (Algorithm)
scenarios = df_all['Scenario'].unique()
algorithms = df_all['Algorithm'].unique()

# Lọc chỉ giữ lại Area và Paper_Fair để vẽ
algorithms = [a for a in algorithms if a in ['CBMP_Area', 'CBMP_Paper_Fair']]

print(f"📊 Scenarios found: {list(scenarios)}")
print(f"🤖 Algorithms to plot: {list(algorithms)}")

# Cấu hình màu sắc và kiểu vẽ cho các thuật toán theo mẫu
style_config = {
    'CBMP_Area': {'color': '#059669', 'marker': 'o', 'linestyle': '-', 'linewidth': 3.5, 'markersize': 9, 'label': 'Cb-MP (CAO-based)'},
    'CBMP_Paper': {'color': '#dc2626', 'marker': 's', 'linestyle': '--', 'linewidth': 3.5, 'markersize': 9, 'label': 'Cb-MP (Count-based)'},
    'CBMP_Paper_Fair': {'color': '#dc2626', 'marker': 's', 'linestyle': '--', 'linewidth': 3.5, 'markersize': 9, 'label': 'Cb-MP (Count-based)'},
    'FixedTime': {'color': '#3b82f6', 'marker': '^', 'linestyle': ':', 'linewidth': 3.0, 'markersize': 9, 'label': 'Fixed Time'}
}

# Lọc df_all chỉ lấy các thuật toán đã chọn để tính Max Y thống nhất
df_plot = df_all[df_all['Algorithm'].isin(algorithms)]
# Gộp các lần chạy để tìm điểm cao nhất của đường trung bình
max_vals = df_plot.groupby(['Scenario', 'Algorithm', 'Cycle'])[['Queue_Length', 'Throughput_per_Cycle', 'Average_Delay']].mean().max()
max_queue = max_vals['Queue_Length'] * 1.05
max_throughput = max_vals['Throughput_per_Cycle'] * 1.05
max_delay = max_vals['Average_Delay'] * 1.05

# 2. Vẽ biểu đồ so sánh và Xuất file Excel cho từng Kịch bản
for scen in scenarios:
    print(f"\n📈 Processing scenario: {scen}...")
    df_scen = df_all[df_all['Scenario'] == scen]
    
    # --- PHẦN 1: XUẤT FILE CSV TỔNG HỢP ĐỂ VẼ BẰNG EXCEL ---
    excel_data = pd.DataFrame()
    
    # --- PHẦN 2: TẠO KHUNG VẼ CHO TỪNG KPI ---
    kpis = [
        ('Queue_Length', 'Average Queue Length (Vehicles)', 'Average Queue Length'),
        ('Throughput_per_Cycle', 'Total Throughput per Cycle (Vehicles)', 'Total Throughput per Cycle'),
        ('Average_Delay', 'Average Vehicle Delay (Seconds)', 'Average Vehicle Delay')
    ]
    
    for ax_idx, (kpi_col, kpi_label, kpi_title) in enumerate(kpis):
        fig, ax = plt.subplots(figsize=(16, 9))
        
        for algo in algorithms:
            df_algo = df_scen[df_scen['Algorithm'] == algo]
            if df_algo.empty:
                continue
                
            # Tính trung bình (mean) và độ lệch chuẩn (std) theo từng Cycle trên 10 lần chạy
            grouped = df_algo.groupby('Cycle')[kpi_col].agg(['mean', 'std']).reset_index()
            
            # Cấu hình style vẽ
            config = style_config.get(algo, {'color': 'gray', 'marker': 'x', 'linestyle': '-', 'linewidth': 3.0, 'markersize': 8, 'label': algo})
            
            # Vẽ đường trung bình cho Matplotlib
            ax.plot(
                grouped['Cycle'], 
                grouped['mean'], 
                color=config['color'], 
                marker=config['marker'], 
                linestyle=config['linestyle'], 
                linewidth=config.get('linewidth', 3.5),
                markersize=config.get('markersize', 9),
                markevery=(0, 4),
                label=config['label']
            )
            
            # --- Tích lũy dữ liệu cho file Excel ---
            if ax_idx == 0: # Chỉ thực hiện gom nhóm và đổi tên cột một lần đối với mỗi thuật toán
                grouped_excel = df_algo.groupby('Cycle').agg({
                    'Queue_Length': 'mean',
                    'Throughput_per_Cycle': 'mean',
                    'Average_Delay': 'mean'
                }).reset_index()
                
                # Đổi tên các cột theo tên thuật toán
                grouped_excel = grouped_excel.rename(columns={
                    'Queue_Length': f'{algo}_Queue_Avg',
                    'Throughput_per_Cycle': f'{algo}_Throughput_Avg',
                    'Average_Delay': f'{algo}_Delay_Avg'
                })
                
                if excel_data.empty:
                    excel_data = grouped_excel
                else:
                    excel_data = pd.merge(excel_data, grouped_excel, on='Cycle', how='outer')
            
        ax.set_title(f"{kpi_title} ({scen})", fontsize=24, fontweight='bold', pad=15)
        ax.grid(True, linestyle='--', alpha=0.35, color='#cccccc')
        ax.legend(loc='lower right', fontsize=22, frameon=True)
        
        # Thống nhất giới hạn trục Y và ép số nguyên
        if kpi_col == 'Queue_Length':
            ax.set_ylim(0, max_queue)
        elif kpi_col == 'Throughput_per_Cycle':
            ax.set_ylim(0, max_throughput)
        elif kpi_col == 'Average_Delay':
            ax.set_ylim(0, max_delay)
        ax.yaxis.set_major_locator(ticker.MaxNLocator(integer=True))
        
        ax.set_xlim(0, 60)
        ax.xaxis.set_major_locator(ticker.MultipleLocator(10))
        ax.tick_params(axis='both', which='major', labelsize=24)
        plt.setp(ax.get_xticklabels(), fontweight='bold')
        plt.setp(ax.get_yticklabels(), fontweight='bold')
        
        plt.tight_layout()
        safe_title = kpi_title.replace(' ', '_')
        plot_path = os.path.join(plots_dir, f"kpi_{safe_title}_{scen}.png")
        plt.savefig(plot_path, dpi=300)
        plt.close(fig)
        print(f"  💾 Saved PNG chart at: {plot_path}")
    
    # Lưu file CSV tổng hợp dùng cho Excel
    if not excel_data.empty:
        # Sắp xếp các cột cho đẹp: Cycle lên đầu, sau đó sắp xếp theo tên cột
        cols = ['Cycle'] + sorted([c for c in excel_data.columns if c != 'Cycle'])
        excel_data = excel_data[cols]
        excel_csv_path = os.path.join(plots_dir, f"excel_data_{scen}.csv")
        excel_data.to_csv(excel_csv_path, index=False)
        print(f"  📊 Exported Excel CSV at: {excel_csv_path}")

print("\n🎉 PROCESSING COMPLETED! PNG charts and Excel CSV files have been saved in the 'plots' directory.")
