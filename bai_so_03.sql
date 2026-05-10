CREATE DATABASE QUANLYCAMDO;
GO
USE QUANLYCAMDO;
GO

-- 1. Bảng Khách hàng---
CREATE TABLE KhachHang (
    MaKH INT PRIMARY KEY IDENTITY(1,1),
    HoTen NVARCHAR(100) NOT NULL,
    SoDienThoai VARCHAR(15),
    SoCCCD VARCHAR(20) UNIQUE NOT NULL
);

-- 2. Bảng Hợp đồng----
CREATE TABLE HopDong (
    MaHD INT PRIMARY KEY IDENTITY(1,1),
    MaKH INT NOT NULL,
    TienGocVay DECIMAL(18, 2) NOT NULL,
    NgayVay DATE DEFAULT GETDATE(),
    Deadline1 DATE NOT NULL, -- Mốc bắt đầu tính lãi kép
    Deadline2 DATE NOT NULL, -- Mốc thanh lý tài sản
    LaiSuatDon FLOAT DEFAULT 0.005, -- 5.000đ/1.000.000đ mỗi ngày[cite: 1]
    TrangThai NVARCHAR(50) DEFAULT N'Đang vay', 
    -- Các trạng thái: Đang vay, Quá hạn (nợ xấu), Đã thanh toán, Đã thanh lý tài sản[cite: 1]
    
    CONSTRAINT FK_HopDong_KhachHang FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH)
);

-- 3. Bảng Tài sản---
CREATE TABLE TaiSan (
    MaTS INT PRIMARY KEY IDENTITY(1,1),
    MaHD INT NOT NULL,
    TenTaiSan NVARCHAR(100) NOT NULL,
    GiaTriDinhGia DECIMAL(18, 2) NOT NULL,
    TrangThaiTS NVARCHAR(50) DEFAULT N'Đang cầm cố',
    -- Trạng thái: Đang cầm cố, Đã trả khách, Sẵn sàng thanh lý, Đã bán thanh lý[cite: 1]
    IsSold BIT DEFAULT 0, -- Cờ đánh dấu đã bán thanh lý[cite: 1]
    
    CONSTRAINT FK_TaiSan_HopDong FOREIGN KEY (MaHD) REFERENCES HopDong(MaHD)
);

-- 4. Bảng Log (Audit Log)---
CREATE TABLE Log (
    MaLog INT PRIMARY KEY IDENTITY(1,1),
    MaHD INT NOT NULL,
    NgayGiaoDich DATETIME DEFAULT GETDATE(),
    SoTienTra DECIMAL(18, 2), -- Số tiền khách trả mỗi lần[cite: 1]
    DuNoConLai DECIMAL(18, 2), -- Dư nợ thực tế sau giao dịch[cite: 1]
    NoiDung NVARCHAR(255), -- Ghi chú biến động trạng thái hoặc số tiền[cite: 1]
    
    CONSTRAINT FK_Log_HopDong FOREIGN KEY (MaHD) REFERENCES HopDong(MaHD)
);
GO

-- 1. Thêm khách hàng
INSERT INTO KhachHang (HoTen, SoDienThoai, SoCCCD) VALUES 
(N'Nguyễn Văn An', '0912345678', '001090123456'),
(N'Trần Thị Bình', '0987654321', '001090654321');

-- 2. Thêm hợp đồng (Test cả khách vay mới và khách quá hạn)
INSERT INTO HopDong (MaKH, TienGocVay, NgayVay, Deadline1, Deadline2, TrangThai) VALUES 
(1, 10000000, '2026-04-01', '2026-05-01', '2026-06-01', N'Đang vay'),
(2, 5000000, '2026-03-01', '2026-04-01', '2026-05-01', N'Quá hạn');

-- 3. Thêm tài sản cầm cố
INSERT INTO TaiSan (MaHD, TenTaiSan, GiaTriDinhGia, TrangThaiTS) VALUES 
(1, N'Xe Honda Vision', 25000000, N'Đang giữ'),
(2, N'iPhone 15 Pro', 20000000, N'Đang giữ'),
(2, N'Laptop Asus', 10000000, N'Đang giữ');

-- 4. Thêm nhật ký trả tiền
INSERT INTO Log (MaHD, NgayGiaoDich, SoTienTra, DuNoConLai, NoiDung) VALUES 
(1, '2026-04-10', 2000000, 8000000, N'Trả bớt gốc lần 1'),
(2, '2026-03-15', 1000000, 4000000, N'Trả bớt gốc');

SELECT 
    K.HoTen AS [Tên Khách], 
    H.TienGocVay AS [Tiền Vay], 
    T.TenTaiSan AS [Tài Sản Cầm]
FROM KhachHang K
JOIN HopDong H ON K.MaKH = H.MaKH
JOIN TaiSan T ON H.MaHD = T.MaHD;

------PHẦN 2------
