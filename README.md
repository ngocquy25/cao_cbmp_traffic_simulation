# ỨNG DỤNG MÔ HÌNH MÔ PHỎNG THEO HƯỚNG DIGITAL TWIN ĐỂ ĐÁNH GIÁ THUẬT TOÁN ĐIỀU KHIỂN ĐÈN GIAO THÔNG LINH HOẠT
*(Digital Twin-Oriented Simulation Framework for Evaluating Adaptive Traffic Signal Control Algorithms)*

---

## 📌 THÔNG TIN ĐỀ TÀI NGHIÊN CỨU KHOA HỌC
* **Cơ quan chủ trì:** Trường Đại học Cần Thơ
* **Loại hình đề tài:** Đề tài Nghiên cứu khoa học của Sinh viên
* **Mã số đề tài:** THS2026-69
* **Chủ nhiệm đề tài:** Sinh viên Nguyễn Thị Ngọc Trân
* **Môi trường mô phỏng:** Nền tảng GAMA Platform (v1.9+)
* **Công cụ phân tích dữ liệu:** Python 3.10+ (Pandas, SciPy, Matplotlib, Seaborn)

---

## 📖 1. GIỚI THIỆU TỔNG QUAN (OVERVIEW)

Tại các đô thị Việt Nam nói chung và TP. Cần Thơ nói riêng, giao thông đặc trưng bởi tỷ lệ xe máy chiếm ưu thế tuyệt đối (trên 85%) với các hành vi di chuyển phức tạp: di chuyển phi làn đường (non-lane-based 2D movement), luồn lách qua khe hở (gap filtering), đảo trật tự hàng chờ và tập hợp thành các cụm dày đặc trước vạch dừng. 

Các thuật toán điều khiển đèn tín hiệu thích ứng kinh điển dựa trên số đếm phương tiện (Count-based Max-Pressure) bộc lộ hạn chế lớn do đánh đồng 1 xe máy tương đương 1 ô tô về mức độ gây áp lực lên nút giao, dẫn đến hiện tượng "áp suất ảo" và phân bổ pha đèn chưa sát với nhu cầu thực tế.

Kho lưu trữ này cung cấp toàn bộ mã nguồn mô phỏng và tập dữ liệu thực nghiệm của đề tài **THS2026-69**, triển khai:
1. **Mô hình mô phỏng vi mô theo hướng Digital Twin:** Xây dựng trên nền tảng GAMA, tái hiện mạng lưới giao thông thực tế 8 nút giao tại quận Ninh Kiều, TP. Cần Thơ; tích hợp **Mô hình tiểu làn (Sub-lane Model)** và **3 hành vi đặc thù của dòng xe máy Việt Nam**.
2. **Thuật toán điều khiển đề xuất CAO-based Cb-MP:** Điều khiển tín hiệu thích ứng chu kỳ dựa trên diện tích chiếm dụng liên tục (Continuous Area Occupancy - CAO), thay thế số đếm phương tiện bằng tỷ lệ diện tích mặt đường thực tế bị chiếm dụng.

---

## 📊 2. KẾT QUẢ THỰC NGHIỆM CỐT LÕI (KEY FINDINGS)

Kết quả đối sánh giữa thuật toán đề xuất **CAO-based Cb-MP** và thuật toán cơ sở **Count-based Cb-MP** qua 60 lượt chạy mô phỏng (chu kỳ 120 giây, 60 chu kỳ điều khiển, 10 lượt chạy hạt giống ngẫu nhiên) trên 3 kịch bản tải:
* **Tải thấp (400 xe/h/nhánh):** Dòng xe thông thoáng.
* **Tải trung bình (900 xe/h/nhánh):** Dòng xe ổn định.
* **Tải cao (1.400 xe/h/nhánh):** Trạng thái quá tải, xuất hiện hàng chờ dồn ứ.

### Các chỉ số định lượng đạt được:
* 📉 **Thời gian trễ trung bình của phương tiện (Average Delay):** Kéo giảm từ **11,2% đến 14,1%** trên toàn bộ các kịch bản tải khảo sát (p < 0,001), mức giảm trễ đạt cao nhất ở tải thấp (giảm 14,1%, từ 20,25s xuống 17,39s).
* 📉 **Chiều dài hàng chờ trung bình (Average Queue Length):** Kéo giảm từ **6,9% đến 8,6%** (p < 0,001), hạn chế nguy cơ ùn ứ lan truyền (spillback) giữa các giao lộ cự ly ngắn (150m – 300m).
* ⚖️ **Bảo toàn lưu lượng thông hành toàn mạng (Network Throughput):** Kiểm định tương đương hai phía TOST (Two One-Sided Tests) với biên khắt khe Delta = ± 2,0% xác nhận tổng số lượng xe thoát qua mạng lưới được bảo toàn tương đương thống kê so với thuật toán cơ sở (độ lệch chỉ từ +0,2% đến +0,6%, p < 0,05).
* 📈 **Độ ổn định hệ thống:** Ở kịch bản tải cao, độ biến động của hàng chờ giảm mạnh, độ lệch chuẩn (SD) giảm từ ± 7,88 xe xuống còn ± 2,74 xe, giúp hệ thống vận hành êm thuận và giảm dao động giật cục.

---

## 📁 3. CẤU TRÚC KHO LƯU TRỮ (REPOSITORY STRUCTURE)

```text
├── models/                     # Mã nguồn mô hình mô phỏng GAMA
│   ├── Intersection.gaml       # Logic điều khiển nút giao, pha đèn và thuật toán CAO/Cb-MP
│   ├── Main.gaml               # Cấu hình thế giới, kịch bản lưu lượng và batch run
│   ├── Road.gaml               # Mô hình mạng lưới đường và tiểu làn (Sub-lane Model)
│   ├── Roi.gaml                # Khởi tạo các vùng quan sát cảm biến (ROI Detection Zones)
│   └── Vehicles.gaml           # Động học IDM/MOBIL và 3 hành vi đặc thù của xe máy
├── includes/                   # Dữ liệu GIS và tài nguyên mô phỏng
│   ├── 2/                      # Shapefiles chuẩn hóa mạng lưới giao thông Q. Ninh Kiều, Cần Thơ
│   └── building_texture/       # Ảnh vân bề mặt công trình đô thị
├── outputs/                    # Dữ liệu thực nghiệm
│   ├── KPI_Result_*.csv        # 60 tệp kết quả mô phỏng thô (10 seeds x 3 mức tải x 2 thuật toán)
│   └── analysis/               # Bảng tổng hợp số liệu kiểm định thống kê Mean ± SD, t-test, TOST
├── plots/                      # Đồ thị chuỗi thời gian KPI qua 60 chu kỳ điều khiển
├── analyze_fair.py             # Script Python tự động phân tích thống kê định lượng
├── plot_kpis.py                # Script Python tự động vẽ biểu đồ KPI chuỗi thời gian
└── export_table_image.py       # Script Python kết xuất hình ảnh bảng số liệu nghiệm thu
