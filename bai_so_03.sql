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
---EVENT 1----
CREATE PROCEDURE sp_CreateContract
    @CustomerID INT,
    @Principal DECIMAL(18,2),
    @Deadline1 DATE,
    @Deadline2 DATE
AS
BEGIN
    INSERT INTO Contract(CustomerID, PrincipalAmount, Deadline1, Deadline2, Status)
    VALUES (@CustomerID, @Principal, @Deadline1, @Deadline2, 'DangVay')
END
GO

----Event 2:Tạo function tính tiền---

CREATE FUNCTION fn_CalcMoneyContract
(
    @ContractID INT,
    @TargetDate DATE
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Principal DECIMAL(18,2)
    DECLARE @Start DATE
    DECLARE @D1 DATE

    SELECT 
        @Principal = PrincipalAmount,
        @Start = StartDate,
        @D1 = Deadline1
    FROM Contract
    WHERE ContractID = @ContractID

    DECLARE @Days1 INT
    SET @Days1 = DATEDIFF(DAY, @Start, 
        CASE WHEN @TargetDate < @D1 THEN @TargetDate ELSE @D1 END)

    DECLARE @SimpleInterest DECIMAL(18,2)
    SET @SimpleInterest = @Principal * 0.005 * @Days1

    IF @TargetDate <= @D1
        RETURN @Principal + @SimpleInterest

    DECLARE @Days2 INT = DATEDIFF(DAY, @D1, @TargetDate)

    DECLARE @Total DECIMAL(18,2)
    SET @Total = (@Principal + @SimpleInterest) * POWER(1.005, @Days2)

    RETURN @Total
END
GO
 ---Event 3---
 CREATE PROCEDURE sp_HandleRepayment
    @MaHD INT,
    @SoTienTra DECIMAL(18, 2)
AS
BEGIN
    DECLARE @TongNoHienTai DECIMAL(18, 2), @TrangThaiHD NVARCHAR(50);
    SET @TongNoHienTai = dbo.fn_CalcMoneyContract(@MaHD, GETDATE());
    
    SELECT @TrangThaiHD = TrangThai FROM HopDong WHERE MaHD = @MaHD;

    -- Kiểm tra nếu đã thanh lý
    IF EXISTS (SELECT 1 FROM TaiSan WHERE MaHD = @MaHD AND IsSold = 1)
    BEGIN
        PRINT N'Tài sản đã bị thanh lý. Không thu tiền.';
        RETURN;
    END

    -- Cập nhật Log và tính nợ còn lại
    DECLARE @ConNo DECIMAL(18,2) = @TongNoHienTai - @SoTienTra;
    
    INSERT INTO Log(MaHD, SoTienTra, DuNoConLai, NoiDung)
    VALUES (@MaHD, @SoTienTra, @ConNo, N'Khách trả nợ một phần');

    -- Cập nhật trạng thái hợp đồng
    IF @ConNo <= 0
    BEGIN
        UPDATE HopDong SET TrangThai = N'Đã thanh toán đủ' WHERE MaHD = @MaHD;
        UPDATE TaiSan SET TrangThaiTS = N'Đã trả khách' WHERE MaHD = @MaHD;
    END
    ELSE
    BEGIN
        UPDATE HopDong SET TrangThai = N'Đang trả góp' WHERE MaHD = @MaHD;
        
        -- Gợi ý trả đồ (Giá trị tài sản còn lại >= Dư nợ)
        SELECT TenTaiSan, GiaTriDinhGia 
        FROM TaiSan 
        WHERE MaHD = @MaHD AND TrangThaiTS = N'Đang cầm cố'
        AND GiaTriDinhGia <= (SELECT SUM(GiaTriDinhGia) FROM TaiSan WHERE MaHD = @MaHD) - @ConNo;
    END
END;
GO

-----Event 4----
CREATE FUNCTION fn_TongTienPhaiTra (
    @MaHD INT,
    @NgayKiemTra DATE
)
RETURNS MONEY
AS
BEGIN
    DECLARE @TongTien MONEY, @TienGoc MONEY, @NgayVay DATE, @Deadline1 DATE, @LaiSuat FLOAT;
    
    -- Lấy thông tin từ hợp đồng
    SELECT @TienGoc = TienGocVay, @NgayVay = NgayVay, @Deadline1 = Deadline1, @LaiSuat = LaiSuatDon
    FROM HopDong WHERE MaHD = @MaHD;

    -- Nếu chưa quá Deadline 1: Tính lãi đơn
    IF @NgayKiemTra <= @Deadline1
    BEGIN
        SET @TongTien = @TienGoc + (@TienGoc * @LaiSuat * DATEDIFF(DAY, @NgayVay, @NgayKiemTra) / 30);
    END
    -- Nếu đã quá Deadline 1: Tính lãi kép (theo công thức lãi mẹ đẻ lãi con)
    ELSE
    BEGIN
        DECLARE @TienTaiDeadline1 MONEY;
        SET @TienTaiDeadline1 = @TienGoc + (@TienGoc * @LaiSuat * DATEDIFF(DAY, @NgayVay, @Deadline1) / 30);
        SET @TongTien = @TienTaiDeadline1 * POWER((1 + @LaiSuat), DATEDIFF(MONTH, @Deadline1, @NgayKiemTra));
    END

    RETURN @TongTien;
END;
GO

---Truy vấn nợ xấu--
DECLARE @NgayHienTai DATE = GETDATE();

SELECT 
    kh.HoTen AS [Tên KH],
    kh.SoDienThoai AS [Số điện thoại],
    hd.TienGocVay AS [Số tiền vay gốc],
    DATEDIFF(DAY, hd.Deadline1, @NgayHienTai) AS [Số ngày quá hạn],
    dbo.fn_TongTienPhaiTra(hd.MaHD, @NgayHienTai) AS [Tổng tiền phải trả hiện tại],
    dbo.fn_TongTienPhaiTra(hd.MaHD, DATEADD(MONTH, 1, @NgayHienTai)) AS [Tổng nợ sau 1 tháng nữa]
FROM KhachHang kh
JOIN HopDong hd ON kh.MaKH = hd.MaKH
WHERE hd.Deadline1 < @NgayHienTai 
  AND hd.TrangThai != N'Đã thanh toán'; 

---Event 5---
-- Trigger 1: Chuyển nợ xấu khi quá Deadline 1
CREATE TRIGGER trg_AutoOverdue
ON HopDong
AFTER UPDATE, INSERT
AS
BEGIN
    UPDATE HopDong 
    SET TrangThai = N'Quá hạn (nợ xấu)'
    WHERE TrangThai = N'Đang vay' AND GETDATE() > Deadline1;
END;
GO

-- Trigger 2: Chuyển trạng thái Tài sản sang Sẵn sàng thanh lý sau Deadline 2
CREATE TRIGGER trg_AutoLiquidateReady
ON HopDong
AFTER UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted i WHERE i.TrangThai = N'Quá hạn (nợ xấu)' AND GETDATE() > i.Deadline2)
    BEGIN
        UPDATE TaiSan 
        SET TrangThaiTS = N'Sẵn sàng thanh lý'
        WHERE MaHD IN (SELECT MaHD FROM inserted WHERE GETDATE() > Deadline2);
    END
END;
GO