# Bai_so_03

  | HỌ VÀ TÊN :Vũ Thị Ánh Tuyết |
## LỚP :k59.KMT.K01


#### Nhiệm vụ 1 : Thiết kế CSDL.

Bước 1: Tạo Database , tạo bảng

<img width="1911" height="1077" alt="image" src="https://github.com/user-attachments/assets/b6aa893d-b2ab-4a54-b0af-682d610db8b5" />

Bước 2: vẽ bảng ERD.

<img width="1904" height="1075" alt="image" src="https://github.com/user-attachments/assets/e70e358a-17b3-45ad-b887-1b7dc00f6bc7" />

<img width="1919" height="1067" alt="image" src="https://github.com/user-attachments/assets/c6efee28-aca1-4b52-a352-678ef1b1eff1" />

Chú thích: Đã có SAMPLE DATA

Sau đó em test thử .
<img width="1918" height="1065" alt="image" src="https://github.com/user-attachments/assets/3f2b063c-e548-4670-8222-cb04a117b713" />

-----

#### NHIỆM VỤ 2: Cài Đặt SQL

##### Event 1: Đăng ký hợp đồng mới (Vay tiền).
Viết Store Procedure tiếp nhận hợp đồng: Lưu thông tin khách hàng, danh sách tài sản 
(kèm giá trị định giá), số tiền vay gốc và thiết lập 2 mốc Deadline1, Deadline2.
 ``` sql
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
```
<img width="1902" height="1072" alt="image" src="https://github.com/user-attachments/assets/c117cef2-4d11-41d0-a350-42f81a93dc10" />

Chú thích :Ảnh này cho thấy em đã tạo hợp đồng mới (VAY TIỀN) thành công.

##### Event 2: Tính toán công nợ thời gian thực
Viết một Function fn_CalcMoneyTransaction(TransactionID, TargetDate) để tính số tiền phải trả của TransactionID này cho đến ngày TargetDate. Viết một Function fn_CalcMoneyContract(ContractID, TargetDate) để tính tổng số tiền khách(ContractID) phải trả (Gốc + Lãi đơn + Lãi kép) tính đến ngày TargetDate. Gợi ý: SV cần sử dụng hàm tính lũy thừa hoặc vòng lặp để xử lý lãi kép.
```sql
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
```
<img width="1919" height="1074" alt="image" src="https://github.com/user-attachments/assets/dd528cc1-e6d7-4dfc-9812-b64d461d21c7" />

Chú thích : Ảnh này cho thấy e đã tạo thành công.

##### Event 3 : : Xử lý trả nợ và hoàn trả tài sản
Viết Viết Store Procedure xử lý khi khách mang tiền đến:
Nếu tài sản đã bị thanh lý (sau Deadline 2 và có cờ IsSold): Thông báo không thu tiền, 
không trả đồ.
Nếu tài sản chưa bị thanh lý: Tính tổng nợ, trừ số tiền khách trả vào hệ thống. Nếu trả hết 
tiền, trả hết đồ và cập nhật trạng thái hợp đồng thành “Đã thanh toán đủ”; Nếu chưa trả
hết tiền gốc+lãi: cập nhật trạng thái hợp đồng thành “Đang trả góp”, ghi nhận vào LOG số
tiền đã trả, và số tiền còn nợ.
Đưa ra danh sách gợi ý trả lại cho khách hàng này dựa trên điều kiện: 
    Giá trị tài sản còn lại >= Dư nợ còn lại.

```sql
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
```
<img width="1911" height="1068" alt="image" src="https://github.com/user-attachments/assets/9fb6b1b8-e83a-4b68-9c5a-a30c5ec10b7f" />

Chú thích : Tạo bảng xử lý trả nợ và hoàn trả tài sản thành công.

##### Event 4: Truy vấn danh sách nợ xấu (Nợ khó đòi)
Xuất danh sách các khách hàng đã quá Deadline 1 mà chưa thanh toán.
Yêu cầu các cột: Tên KH, Số điện thoại, Số tiền vay gốc, Số ngày quá hạn, Tổng tiền phải 
trả hiện tại (đến ngày hiện tại), Tổng số tiền phải trả sau 1 tháng nữa.
Gợi ý: Nên viết function hỗ trợ.
Bước 1 : Viết FUNCTION tính tổng tiền phải trả.
```sql
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
```
<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/71b6a0d2-0a25-49d0-ad38-21cc77261357" />
 Chú thích :Tạo bảng thành công
 
 Bước 2 : Truy vấn.
 
```sql
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
```
 <img width="1914" height="1076" alt="image" src="https://github.com/user-attachments/assets/3d098559-49ac-4246-bd9e-ad76bdb92bd9" />

##### Event 5:  Quản lý thanh lý tài sản
Viết một Trigger tự động chuyển trạng thái hợp đồng sang "Quá hạn (nợ xấu)" sau khi hợp 
đồng đang ở trạng thái "Đang vay" mà ngày vượt quá Deadline 1.
Viết một Trigger tự động chuyển trạng thái tài sản sang "Sẵn sàng thanh lý" sau khi hợp 
đồng đang ở trạng thái "Quá hạn (nợ xấu)" mà ngày vượt quá Deadline 2.
Viết một Trigger tự động chuyển trạng thái tài sản thành “Đã bán thanh lý” sau khi trạng 
thái của hợp đồng chuyển sang "Đã thanh lý".
Chú ý: Mỗi tài sản cũng được theo dõi trạng thái: đang cầm cố, đã trả khách, đã bán thanh lý.
```sql
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
```
<img width="1912" height="1076" alt="image" src="https://github.com/user-attachments/assets/12ed3405-e064-466b-b3e7-86034853a3e5" />

