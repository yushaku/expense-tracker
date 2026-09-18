# Hướng dẫn Apple Pay Capture Shortcut

Hướng dẫn từng bước để tạo shortcut gửi giao dịch Apple Pay vào MonMon, kiểm tra
trên iPhone và chia sẻ qua iCloud để người khác không phải tự dựng các trường dữ liệu.

Tên nút dưới đây dùng tiếng Anh kèm giải thích tiếng Việt; giao diện có thể khác theo
ngôn ngữ và phiên bản iOS. Thuộc tính Wallet và việc truyền dữ liệu qua Run Shortcut
cần được xác nhận trên iPhone trước khi công bố link. Tài liệu này không xác nhận
rằng một shortcut chia sẻ đã được tạo hoặc đã chạy thành công.

## 1. Phân biệt shortcut và automation

Cần hai thành phần, không phải hai shortcut:

- **Shortcut “MonMon — Apple Pay Capture”**: nhận dữ liệu giao dịch và gửi vào
  MonMon. Bạn tạo một lần rồi chia sẻ link iCloud.
- **Automation Wallet**: khi chạm thẻ Apple Pay đã chọn, gọi shortcut trên và truyền
  dữ liệu vào. Mỗi người phải tự thiết lập trên iPhone và chọn thẻ của mình.

Cài shortcut từ link không tự tạo automation. Apple xác định automation cá nhân
gắn với thiết bị, không đồng bộ sang thiết bị khác:
[Personal automation](https://support.apple.com/en-asia/guide/shortcuts/apd690170742/ios).

## 2. Chuẩn bị trong MonMon

1. Mở **MonMon Dev** nếu đang thử nghiệm, hoặc **MonMon** có tính năng Apple Pay capture.
2. Vào **Settings → Quick Capture Shortcut → Apple Pay capture**.
3. Chọn **Destination account** là tài khoản VND tương ứng với thẻ dùng thanh toán.
4. Tạm thời tắt **Automatically save Apple Pay expenses** để kiểm tra dữ liệu trước.

Shortcut dùng action của **MonMon Dev** yêu cầu người nhận cài MonMon Dev. Bản chia sẻ
cho người dùng thông thường phải dùng action của **MonMon**, và phiên bản họ cài phải
có action **Record Apple Pay Transaction**. Đổi tên shortcut không đổi ứng dụng mà
action gọi. Nên thử bằng Dev trước, sau đó tạo bản dùng action MonMon và kiểm tra lại.

## 3. Tạo shortcut dùng chung

### 3.1. Tạo shortcut mới

1. Mở **Shortcuts / Phím tắt** trên iPhone.
2. Vào tab **Shortcuts**, chưa vào Automation.
3. Nhấn **+** để tạo shortcut.
4. Đặt tên **MonMon — Apple Pay Capture**.

### 3.2. Thêm ngày ghi nhận

1. Tìm action **Date / Ngày**.
2. Thêm action này và để chế độ **Current Date / Ngày hiện tại**.

Kết quả action này là thời điểm shortcut chạy, không phải ngày ngân hàng quyết toán.
Nếu Wallet cung cấp ngày sự kiện, có thể dùng ngày đó thay thế. Nếu dùng Current Date,
lấy một lần cho mỗi lần chạy và dùng kết quả ấy ở action MonMon.

### 3.3. Thêm action của MonMon

1. Tìm **MonMon Dev** hoặc **MonMon**, đúng ứng dụng đang thử.
2. Chọn **Record Apple Pay Transaction / Ghi giao dịch Apple Pay**.
3. Đặt action này bên dưới action Date.

Không chọn action ghi giao dịch thông thường hoặc bank notification.

### 3.4. Điền Amount bằng biến

Không nhập số tiền cố định hoặc gõ chữ “Shortcut Input” vào ô.

1. Chạm hoặc nhấn giữ ô **Amount** để chọn biến.
2. Chọn **Shortcut Input / Đầu vào phím tắt**.
3. Chạm lại vào viên biến vừa chèn để mở thuộc tính.
4. Chọn thuộc tính **Amount** của giao dịch.

Nếu chưa thấy Amount:

- Kiểm tra mục **Type / Loại** của biến.
- Nếu có **Transaction / Giao dịch**, chọn loại đó rồi chọn Amount.
- Nếu không có Transaction hoặc Amount, dừng ở đây và chụp menu để kiểm tra.
  Không chọn đại Text hoặc Number. Tài liệu Apple không liệt kê đầy đủ thuộc tính
  Wallet trên từng bản iOS; cần xác nhận giao diện thực tế trước khi tiếp tục.

**Giữ Amount kèm tiền tệ.** Không đưa qua action chuyển thành Number hoặc Text:
MonMon nhận `IntentCurrencyAmount`, gồm cả số tiền và mã tiền tệ.

Cách mở biến, đổi loại và chọn thuộc tính được Apple mô tả tại
[Adjust variables](https://support.apple.com/en-lamr/guide/shortcuts/apda36b9018b/ios).

### 3.5. Điền Merchant bằng biến

1. Chạm hoặc nhấn giữ ô **Merchant**.
2. Chọn **Shortcut Input**.
3. Chạm lại vào viên biến.
4. Chọn thuộc tính **Merchant**, tức tên nơi thanh toán.

Không gõ chữ “Merchant” thành văn bản. Nếu thiếu thuộc tính này, kiểm tra Type như
ở bước Amount; không điền tên cửa hàng cố định vào bản chia sẻ.

### 3.6. Hoàn thành các trường

| Trường của action MonMon | Giá trị |
| --- | --- |
| Amount | Biến Shortcut Input, thuộc tính Amount, giữ tiền tệ |
| Merchant | Biến Shortcut Input, thuộc tính Merchant |
| Transaction date | Kết quả action Date ở phía trên; hoặc ngày sự kiện nếu có |
| Account | Để trống ở bản chia sẻ |
| Card label | Để trống ở bản chia sẻ |

Mở phần mở rộng của action nếu Account hoặc Card label đang bị ẩn.

Account để trống sẽ dùng tài khoản mỗi người chọn trong phần Apple Pay capture của
MonMon. Không chọn tài khoản riêng của người tạo hoặc Ask Each Time trong bản chia sẻ.
Card label là tùy chọn; nếu dùng thì chỉ ghi nhãn thẻ, không ghi đầy đủ số thẻ.

Lưu shortcut. Chưa dùng nút **▶** để kiểm tra giao dịch: chạy trực tiếp tại đây chưa
có dữ liệu Wallet truyền vào.

## 4. Tạo automation Wallet gọi shortcut

1. Mở tab **Automation / Tự động hóa** trong Shortcuts.
2. Nhấn **+** để tạo automation.
3. Tìm **Transaction / Giao dịch**, thuộc Wallet.
4. Ở **When I tap**, chọn thẻ Apple Pay muốn theo dõi.
5. Chọn **Run Immediately / Chạy ngay lập tức** nếu có.
6. Nhấn **Next / Tiếp**.
7. Chọn **New Blank Automation** nếu màn hình có lựa chọn này.
8. Thêm action **Run Shortcut / Chạy phím tắt**.
9. Chọn **MonMon — Apple Pay Capture** vừa tạo.
10. Mở phần mở rộng của action Run Shortcut.
11. Ở **Input / Đầu vào**, chọn **Shortcut Input** của automation, tức dữ liệu
    giao dịch Wallet vừa kích hoạt.
12. Giữ nguyên toàn bộ giao dịch ở Input này, không chỉ chọn Amount hoặc Merchant.
13. Lưu automation.

Điểm dễ bỏ sót: **Run Shortcut phải truyền dữ liệu đầu vào**, không chỉ gọi tên
shortcut. Nếu không thấy Input hoặc biến giao dịch, chụp phần mở rộng của Run Shortcut
để kiểm tra trước khi thử thanh toán.

Apple mô tả trigger này là chạy khi thẻ được chọn được chạm; không phải cơ chế đọc
toàn bộ lịch sử Wallet: [Transaction triggers](https://support.apple.com/en-lamr/guide/shortcuts/apd65c67538a/ios).

## 5. Kiểm tra trên iPhone trước khi chia sẻ

Ở lần thanh toán Apple Pay thực tế tiếp theo:

1. Dùng đúng thẻ đã chọn trong automation.
2. Nếu iOS yêu cầu quyền chạy hoặc chuyển dữ liệu cho MonMon, đọc và cho phép nếu phù hợp.
3. Mở **MonMon → Transactions → Needs review** trong đúng ứng dụng Dev hoặc MonMon.
4. Kiểm tra số tiền, tiền tệ, nơi thanh toán, thời điểm và tài khoản nhận.
5. Khi dữ liệu đã đúng, bật **Automatically save Apple Pay expenses** nếu muốn tự lưu.

MonMon mặc định giữ capture để duyệt, chưa cộng vào tổng giao dịch. Tự lưu yêu cầu
số tiền VND nguyên, dương, dưới 1.000.000.000.000.000, merchant, tài khoản VND hợp lệ
và danh mục chi mặc định. Thiếu dữ liệu hoặc tiền tệ không hỗ trợ sẽ cần duyệt;
MonMon không tự đổi ngoại tệ thành VND.

### Các giới hạn cần biết

- Wallet có thể không gửi đủ dữ liệu hoặc không kích hoạt. Chạm thẻ không chứng minh
  ngân hàng đã quyết toán; tính năng không nhập lịch sử Wallet.
- Dùng một nguồn tự động cho mỗi thẻ. Apple Pay và bank notification có thể tạo hai
  giao dịch cho cùng khoản thanh toán; chống trùng giữa hai nguồn vẫn là TODO.
- Retry phải giữ các trường gốc, tài khoản và ngày gốc. Chạy lại với Current Date mới
  có thể tạo capture mới; không dùng việc chạy lặp để thử chống trùng.
- Bản chia sẻ để Account trống dùng một tài khoản mặc định. Nếu nhiều thẻ cần vào
  nhiều tài khoản khác nhau, người dùng cần bản shortcut riêng có Account tương ứng
  cho từng thẻ, rồi chọn đúng bản trong từng automation.

### Nếu chưa thấy capture

1. Kiểm tra automation đã bật và chọn đúng thẻ.
2. Kiểm tra Run Shortcut gọi đúng shortcut, có truyền toàn bộ Shortcut Input.
3. Kiểm tra Amount và Merchant là thuộc tính của biến, không phải văn bản gõ tay.
4. Kiểm tra action thuộc MonMon hay MonMon Dev và mở đúng ứng dụng đó.
5. Xem **Needs review** ở Transactions; không tìm Recent activity trong Settings.
6. Ghi lại lỗi Shortcuts nếu có; che thông tin thanh toán riêng trước khi chia sẻ ảnh.

## 6. Tạo link chia sẻ iCloud

Chỉ công bố sau khi đã kiểm tra luồng Wallet → Run Shortcut → MonMon trên iPhone.

1. Mở tab **Shortcuts**.
2. Nhấn **…** trên **MonMon — Apple Pay Capture** để mở trình sửa.
3. Kiểm tra Account và Card label không chứa thông tin riêng; Amount và Merchant
   không chứa dữ liệu mẫu hoặc giá trị cố định.
4. Kiểm tra action dùng đúng MonMon cho đối tượng nhận, không nhầm MonMon Dev.
5. Nhấn biểu tượng **Share / Chia sẻ**.
6. Chọn **Copy iCloud Link**.
7. Xác nhận **Copy Link** nếu được hỏi.
8. Gửi link cho người thử nghiệm và kiểm tra họ thêm, cấu hình, sử dụng được trước
   khi chia sẻ rộng rãi.

Người nhận mở link để thêm shortcut vào bộ sưu tập của họ. Các bước chia sẻ chính thức:
[Share shortcuts](https://support.apple.com/en-mide/guide/shortcuts/apdf01f8c054/ios).

Link thử nghiệm dùng MonMon Dev chỉ dành cho người có MonMon Dev. Không tạo link giả
hoặc coi shortcut là sẵn sàng cho người dùng MonMon khi chưa kiểm tra đúng bản app.

## 7. Hướng dẫn ngắn gửi cho người dùng cuối

1. Cài và mở phiên bản MonMon có Apple Pay capture.
2. Vào **Settings → Quick Capture Shortcut → Apple Pay capture**, chọn tài khoản nhận.
3. Mở link iCloud do người phát hành cung cấp, chọn thêm shortcut.
4. Tạo **Wallet / Transaction automation**, chọn thẻ và chế độ chạy ngay nếu có.
5. Thêm **Run Shortcut**, chọn shortcut vừa cài, truyền toàn bộ **Shortcut Input**.
6. Kiểm tra giao dịch đầu tiên trong **Transactions → Needs review**.
7. Chỉ bật tự lưu khi dữ liệu đúng; không dùng thêm bank notification capture cho
   cùng khoản thanh toán.

Người dùng không phải dựng lại các trường Amount, Merchant và Date; họ chỉ cài
shortcut, chọn tài khoản trong MonMon và kết nối automation với thẻ của mình.

Chi tiết kỹ thuật: [Apple Pay capture spec](apple-pay-capture-spec.md).
