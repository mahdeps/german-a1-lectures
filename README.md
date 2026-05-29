# German A1 — المحاضرات

موقع لتحميل محاضرات دورة اللغة الألمانية للمستوى A1: فيديوهات، ملفات صوتية، وملخصات تفاعلية.

🌐 **الموقع:** _(يُضاف رابط GitHub Pages بعد النشر)_

## كيف يعمل
- **الموقع** (`index.html` + `manifest.json` + `notes/` + `pdf/`) مستضاف على **GitHub Pages**.
- **الفيديوهات والصوتيات الكبيرة** مرفوعة كأصول على **GitHub Releases** (لأن GitHub لا يقبل ملفات أكبر من 100MB داخل المستودع).
- الموقع يقرأ `manifest.json` ويبني أزرار التحميل تلقائياً.

## إعادة بناء البيانات
إذا أضفت أو غيّرت محاضرات داخل مجلدات `المحاضرة N`:

```powershell
.\build-manifest.ps1      # يفحص المجلدات ويولّد manifest.json + upload-map.json
.\upload-videos.ps1       # يرفع الفيديوهات/الصوتيات الجديدة إلى الـ Release
git add -A; git commit -m "update lectures"; git push
```

## الملفات
| الملف | الوصف |
|------|-------|
| `index.html` | الموقع نفسه (تصميم واحد، بدون اعتماديات) |
| `manifest.json` | قائمة المحاضرات وروابط التحميل (يُنشأ آلياً) |
| `notes/`, `pdf/` | الملخصات التفاعلية وملفات PDF |
| `build-manifest.ps1` | يفحص المجلدات ويبني الـ manifest |
| `upload-videos.ps1` | يرفع الوسائط الكبيرة إلى GitHub Releases |
