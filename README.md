# Mycelium — โรงเรือนเพาะเห็ดอัจฉริยะ 🍄

โครงงาน IoT รหัสท้าย 224 จำลองเซนเซอร์บน ESP32 ด้วย ESPHome ตามรูปแบบ L1–L5 ของเอกสารอาจารย์ โดยขยายเป็น 6 ฟิลด์ + Unix timestamp และใช้ path ที่ root ตามโจทย์จริง

**ส่ง Classroom เพียง URL นี้:** https://wiwatpromwihan.github.io/freeboard/

Database URL: https://iot-224-default-rtdb.asia-southeast1.firebasedatabase.app

## สถาปัตยกรรม

```text
ESP32 / ESPHome (esp32dev, esp-idf)
  └─ Wi-Fi + SNTP พร้อม → ทุก 10 วินาที
      ├─ HTTPS PUT  /latest.json  → ค่าล่าสุด
      └─ HTTPS POST /history.json → ประวัติพร้อม timestamp
                    │
               Firebase RTDB: iot-224-default-rtdb
                    │ Firebase JS SDK / onValue
          GitHub Pages /freeboard/ → Realtime Dashboard
```

Project ID: `iot-224` • Region: `asia-southeast1` • Repo: `freeboard`
ไม่มี `/lab` หรือ device ID นำหน้า และไม่มี backend server บน GitHub Pages

## ข้อมูล 7 ฟิลด์

| Field | ความหมาย | หน่วย | ช่วงสุ่ม |
|---|---|---|---|
| air_temperature | อุณหภูมิอากาศ | °C | 24–32 |
| air_humidity | ความชื้นอากาศ | % | 75–95 |
| co2 | คาร์บอนไดออกไซด์ | ppm | 450–1,800 |
| substrate_moisture | ความชื้นวัสดุเพาะ | % | 55–75 |
| illuminance | ความสว่าง | lx | 100–800 |
| water_level | ระดับน้ำในถังพ่นหมอก | % | 20–100 |
| timestamp | เวลา SNTP | Unix seconds | เวลาที่ส่งจริง |

เซนเซอร์เป็น `platform: template` สุ่มทุก 5 วินาทีด้วย `min + random_float() * (max - min)` ไม่ใช่การอ่านเซนเซอร์จริง ช่วงเหล่านี้ใช้จำลองงานเรียน ไม่ใช่คำแนะนำการเพาะเห็ดทุกสายพันธุ์

## ไฟล์

- `project-final.yaml`: ESPHome ตาม pattern L5 ส่ง PUT ก่อน POST พร้อม log แยก Latest / History
- `database.rules.json`: ปิด root เปิดเฉพาะ latest และ history พร้อม index timestamp
- `firebase.json`, `.firebaserc`: ตั้งค่า deploy ไปฐานข้อมูลที่ถูกต้อง
- `index.html`, `firebase-config.js`: Dashboard responsive, Firebase JS SDK และ Chart.js
- `setup.sh`: ตั้งค่า Firebase, GitHub และ Pages รันซ้ำได้โดยตรวจทรัพยากรก่อน
- `flash.sh`, `requirements.txt`: ติดตั้ง ESPHome 2026.8.2, compile และ upload ผ่าน USB
- `secrets.example.yaml`: ตัวอย่าง Wi-Fi ไม่มีรหัสจริง

## Setup ผ่าน CLI

ต้องมีบัญชี Google / GitHub ที่ยืนยันแล้ว, Node.js รุ่นที่ Firebase CLI รองรับ, Git และ GitHub CLI (`gh`) บัญชี GitHub เป้าหมายคือ `wiwatpromwihan`

```bash
npm install -g firebase-tools
git clone https://github.com/wiwatpromwihan/freeboard.git
cd freeboard
bash setup.sh
```

ถ้ายังไม่ login สคริปต์เรียก `firebase login` และ `gh auth login --web` ให้ยืนยันผ่านเบราว์เซอร์ จากนั้นหยุดรอด้วยข้อความ “กรุณากดยืนยันในเบราว์เซอร์แล้วกด Enter เพื่อทำต่อ” หาก login แล้วจะใช้บัญชีปัจจุบัน

สคริปต์สร้าง `firebase projects:create iot-224` เมื่อไม่มีโปรเจค และลอง `firebase database:instances:create iot-224-default-rtdb --project iot-224 --location asia-southeast1` ตามชื่อ instance ที่ยืนยันแล้ว

**ฐานข้อมูลแรก:** Firebase CLI อาจแจ้งให้ใช้ `firebase init database` สคริปต์จะเปิดขั้นตอนนี้ในโฟลเดอร์ชั่วคราว ให้เลือกสร้างฐานข้อมูลและ region `asia-southeast1` สคริปต์ตรวจชื่อและ URL จริงก่อน deploy หาก Project ID ถูกผู้อื่นใช้หรือไม่มีสิทธิ์จะหยุด ไม่เปลี่ยน `iot-224` เอง

จากนั้น deploy rules, ดึง Web App config, สร้าง repo `freeboard` หากยังไม่มี หรือ push repo เดิม และเปิด Pages จาก branch `main` ที่ root ผ่าน `gh api` สคริปต์ไม่ force push หาก repo มีประวัติใหม่กว่าจะหยุดให้จัดการก่อน URL เว็บอาจยังใช้ไม่ได้ทันที ต้องรอ Pages build เสร็จ

## Wi-Fi และ USB flash

ใช้ ESP32 DevKit (`esp32dev`) กับสาย USB ที่ส่งข้อมูลได้ และเครือข่าย Wi-Fi 2.4 GHz ที่ออกอินเทอร์เน็ตได้

```bash
cp secrets.example.yaml secrets.yaml
# แก้ secrets.yaml ใส่ SSID และรหัสผ่านจริงบนเครื่อง
chmod 600 secrets.yaml
# macOS: ตรวจพอร์ตอีกครั้งทุกครั้งที่เสียบอุปกรณ์
ls /dev/cu.*
# Linux ใช้ /dev/ttyUSB* หรือ /dev/ttyACM*
```

`secrets.yaml` อยู่ใน `.gitignore` ห้าม commit หรือส่งรหัสผ่านขึ้น GitHub ตอนตั้งค่าเครื่องนี้พบ `/dev/cu.usbserial-10` แต่พอร์ตอาจเปลี่ยนเมื่อเสียบใหม่

ต้องมี Python 3.12 ขึ้นไป สำหรับเครื่องนี้ติดตั้ง ESPHome ไว้ที่ `~/.local/share/iot-224/venv` แล้ว ใช้สคริปต์ช่วย compile และ upload:

```bash
./flash.sh /dev/cu.usbserial-10
```

หากยังไม่มี environment และ `python3` เก่า ให้ระบุ Python รุ่นใหม่ เช่น `PYTHON=python3.12 ./flash.sh /dev/cu.usbserial-10`

สคริปต์คัดลอก YAML และ secrets ไป `~/.local/share/iot-224/firmware` แล้วรันคำสั่งต่อไปนี้จริง (ใช้พื้นที่นี้เพราะชื่อโฟลเดอร์รายวิชามี `:` ซึ่งไม่เหมาะกับ Python venv และ build tools):

```bash
cd "$HOME/.local/share/iot-224/firmware"
"$HOME/.local/share/iot-224/venv/bin/esphome" config project-final.yaml
"$HOME/.local/share/iot-224/venv/bin/esphome" compile project-final.yaml
"$HOME/.local/share/iot-224/venv/bin/esphome" upload project-final.yaml --device /dev/cu.usbserial-10
"$HOME/.local/share/iot-224/venv/bin/esphome" logs project-final.yaml --device /dev/cu.usbserial-10
```

หากค้าง Connecting ให้กด BOOT ค้างช่วงเริ่ม upload แล้วปล่อยเมื่อเริ่มเขียน แฟลชจะเขียนทับ firmware เดิมบนบอร์ด

## ตรวจการทำงาน

1. Log ต้องเชื่อม Wi-Fi และแสดง `Time synchronized` ก่อนส่ง หากยังไม่พร้อมจะเห็น `Skip Firebase: WiFi or time not ready`
2. เห็น `Latest HTTP status = 200` และ `History HTTP status = 200` ทุกประมาณ 10 วินาที
3. Firebase มี `/latest` ครบ 7 ฟิลด์ และ `/history` เพิ่มรายการ push key ใหม่
4. เปิด Dashboard แล้วค่าการ์ดและกราฟเปลี่ยนเองโดยไม่กด refresh
5. ถอด USB แล้วหลัง 40 วินาทีหน้าเว็บจะระบุข้อมูลอุปกรณ์ยังไม่อัปเดต แม้เว็บยังเชื่อม Firebase อยู่

กราฟเลือกดูได้ครบ 6 ค่า โดย subscribe `query(ref(db, 'history'), orderByChild('timestamp'), limitToLast(120))` และใช้ `onValue` ไม่มี polling ข้อมูล ทุก 5 วินาทีมีเพียงการตรวจอายุ timestamp บนหน้าเว็บเพื่อแสดงสถานะเท่านั้น เวลาแสดงเป็น Asia/Bangkok ส่วนข้อมูลเก็บเป็น Unix seconds

PUT และ POST เป็นสอง request แยกกัน ไม่ atomic; request หนึ่งอาจสำเร็จแต่อีกอันล้มเหลวได้ timestamp อ่านจาก SNTP ในแต่ละ request ตาม L5 จึงอาจต่างกันเล็กน้อย ประวัติสะสมประมาณ 8,640 รายการ/วัน การจำกัด 120 รายการบนเว็บไม่ลบข้อมูลเก่า

## ข้อจำกัดและ Rules งานเรียน

**Rules นี้เหมาะกับงานส่งการบ้านเท่านั้น ไม่ควรใช้ production จริง** แม้ root ปิด แต่ทุกคนที่ทราบ URL อ่าน/เขียน/ลบข้อมูลภายใต้ `/latest` และ `/history` ได้ ระบบจริงต้องมี Authentication และ validation ตามสิทธิ์อุปกรณ์

`firebase-config.js` เป็น public web config ไม่ใช่ admin key การป้องกันข้อมูลขึ้นกับ Rules ห้ามอัปโหลด service-account keys, login tokens, secrets.yaml หรือ firmware ที่ฝัง Wi-Fi

หน้าเว็บต้องเข้าถึง Firebase, gstatic, jsDelivr และ Google Fonts ผ่านอินเทอร์เน็ต หาก CDN กราฟโหลดไม่ได้มีข้อความแจ้ง และข้อมูลการ์ดยังทำงานได้ อย่าเปิด index.html ผ่าน file:// ให้ใช้ Pages หรือ HTTP server

## เอกสารอ้างอิง

- เอกสารอาจารย์ Copy of ESP32-Firebase-GitHub.docx.pdf ส่วน L5 หน้า 22–25 (ไม่รวม PDF ใน repo)
- https://esphome.io/components/http_request/
- https://firebase.google.com/docs/database/web/read-and-write
- https://firebase.google.com/docs/cli
- https://docs.github.com/en/rest/pages/pages
