#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PROJECT=iot-224
INSTANCE=iot-224-default-rtdb
REGION=asia-southeast1
EXPECTED_OWNER=wiwatpromwihan
pause_browser() {
  echo 'กรุณากดยืนยันในเบราว์เซอร์แล้วกด Enter เพื่อทำต่อ'
  read -r
}
for tool in node npm git gh firebase; do
  command -v "$tool" >/dev/null || { echo "ไม่พบ $tool: ติดตั้ง Node.js, Git, GitHub CLI และ npm install -g firebase-tools ก่อน"; exit 1; }
done
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
if ! firebase projects:list --json > "$scratch/projects.json"; then
  echo 'Firebase login: กรุณายืนยันบัญชี Google ในเบราว์เซอร์'
  firebase login
  pause_browser
  firebase projects:list --json > "$scratch/projects.json"
fi
if ! node -e 'const d=require(process.argv[1]);process.exit(d.result.some(p=>p.projectId==="iot-224")?0:1)' "$scratch/projects.json"; then
  # Never substitute another project ID if iot-224 is unavailable.
  firebase projects:create iot-224 --display-name iot-224
fi
firebase database:instances:list --project "$PROJECT" --json > "$scratch/instances.json"
if ! node -e 'const d=require(process.argv[1]);process.exit(d.result.some(p=>p.name.split("/").pop()==="iot-224-default-rtdb")?0:1)' "$scratch/instances.json"; then
  if ! firebase database:instances:create iot-224-default-rtdb --project iot-224 --location asia-southeast1; then
    echo 'ฐานข้อมูลแรกต้องใช้ firebase init database: เลือก Yes และ asia-southeast1'
    echo 'หากเกิดปัญหาสิทธิ์หรือชื่อซ้ำ ให้แก้ปัญหาโดยคง Project ID iot-224'
    # Initialize in a temporary directory so the classroom rules are preserved.
    (cd "$scratch" && firebase init database --project iot-224)
  fi
fi
firebase database:instances:list --project "$PROJECT" --json > "$scratch/instances.json"
DATABASE_URL=$(node - "$scratch/instances.json" <<'JS'
const d=require(process.argv[2]);const x=d.result.find(p=>p.name.split('/').pop()==='iot-224-default-rtdb');
if(!x||!x.databaseUrl||!x.databaseUrl.includes('.asia-southeast1.firebasedatabase.app')){throw Error('ไม่พบ database instance ใน region ที่กำหนด กรุณาตรวจ Firebase Console');}
process.stdout.write(x.databaseUrl.replace(/\/$/,''));
JS
)
firebase deploy --only database --project iot-224
firebase apps:list WEB --project "$PROJECT" --json > "$scratch/apps.json"
APP_ID=$(node -e 'const d=require(process.argv[1]);const apps=Array.isArray(d.result)?d.result:d.result.apps;process.stdout.write((apps.find(a=>a.displayName==="mushroom-dashboard")||{}).appId||"")' "$scratch/apps.json")
if [ -z "$APP_ID" ]; then
  firebase apps:create WEB mushroom-dashboard --project "$PROJECT" --json > "$scratch/app.json"
  APP_ID=$(node -e 'process.stdout.write(require(process.argv[1]).result.appId)' "$scratch/app.json")
fi
firebase apps:sdkconfig WEB "$APP_ID" --project "$PROJECT" --json > "$scratch/sdk.json"
node - "$scratch/sdk.json" "$DATABASE_URL" <<'JS'
const fs=require('fs');const r=JSON.parse(fs.readFileSync(process.argv[2])).result;
const config=r.sdkConfig||JSON.parse(r.fileContents);config.databaseURL=process.argv[3];
fs.writeFileSync('firebase-config.js','// Public Firebase web configuration, not an admin credential.\nexport const firebaseConfig = '+JSON.stringify(config,null,2)+';\n');
let yaml=fs.readFileSync('project-final.yaml','utf8');
yaml=yaml.replace(/https:\/\/[^\s"]+\/(latest|history)\.json/g,(_,path)=>`${config.databaseURL}/${path}.json`);
fs.writeFileSync('project-final.yaml',yaml);
JS
if ! gh auth status >/dev/null 2>&1; then
  echo 'GitHub login: กรุณายืนยันบัญชีในเบราว์เซอร์'
  gh auth login --hostname github.com --git-protocol https --web
  pause_browser
fi
OWNER=$(gh api user --jq .login)
[ "$OWNER" = "$EXPECTED_OWNER" ] || { echo "กรุณาใช้บัญชี GitHub $EXPECTED_OWNER (ตอนนี้เป็น $OWNER)"; exit 1; }
gh auth setup-git
if [ ! -d .git ]; then git init -b main; fi
if [ -n "$(git branch --show-current)" ] && [ "$(git branch --show-current)" != main ]; then
  echo 'กรุณารันจาก branch main เพื่อไม่แก้ branch เดิมโดยอัตโนมัติ'; exit 1
fi
if ! git config user.name >/dev/null; then git config user.name "$OWNER"; fi
if ! git config user.email >/dev/null; then
  GH_ID=$(gh api user --jq .id)
  git config user.email "$GH_ID+$OWNER@users.noreply.github.com"
fi
# Stage only deliverables; never secrets, environment, or firmware binaries.
git add .gitignore .nojekyll .firebaserc firebase.json database.rules.json index.html firebase-config.js project-final.yaml secrets.example.yaml setup.sh flash.sh README.md requirements.txt
if ! git diff --cached --quiet; then git commit -m 'Build mushroom greenhouse realtime IoT dashboard'; fi
if gh repo view "$OWNER/freeboard" >/dev/null 2>&1; then
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/$OWNER/freeboard.git"
  fi
  case "$(git remote get-url origin)" in
    "https://github.com/$OWNER/freeboard.git"|"git@github.com:$OWNER/freeboard.git"|"https://github.com/$OWNER/freeboard") ;;
    *) echo 'origin ไม่ตรงกับ repo ที่กำหนด'; exit 1;;
  esac
  git push -u origin main
else
  gh repo create freeboard --public --source=. --push
fi
if gh api "repos/$OWNER/freeboard/pages" > "$scratch/pages.json" 2>/dev/null; then
  gh api --method PUT "repos/$OWNER/freeboard/pages" -f 'source[branch]=main' -f 'source[path]=/' >/dev/null
else
  gh api --method POST "repos/$OWNER/freeboard/pages" -f 'source[branch]=main' -f 'source[path]=/' >/dev/null
fi
printf '\nDatabase URL: %s\nDashboard URL: https://%s.github.io/freeboard/\n' "$DATABASE_URL" "$OWNER"
echo 'ส่ง Classroom เฉพาะ Dashboard URL • GitHub Pages อาจใช้เวลาสักครู่ในการเผยแพร่'
