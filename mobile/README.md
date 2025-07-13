# AutoMark – Smart Grading Assistant 📱

AutoMark is a mobile and web-based system designed to help educators automatically grade student exam scripts using OCR (Optical Character Recognition) and RESTful APIs. It allows scripts to be scanned, answers extracted and compared against an answer key, with logic-based scoring, grading, and optional manual override. It also integrates payment handling via MTN Mobile Money API for advanced features.

---

## 📱 Mobile App (Flutter)

The Flutter mobile app allows:
- 📷 Capturing or uploading answer scripts
- 🔎 Extracting text using OCR (Google ML Kit)
- 🧠 Comparing answers to a lecturer-provided key
- 🧮 Logic-based auto-marking and grading
- ✍ Manual adjustment of marks
- 📊 Viewing total scores and grades
- 💰 Payment (via MTN MoMo API) for additional features like bulk grading, analytics, or report access

> The mobile app is located in the /mobile folder.

---

## 🌐 Project Website

The static website provides:
- 📘 Overview of the project
- 👩‍💻 Team roles and contributions
- 📸 Screenshots of the app UI
- 🔗 Link to GitHub repository
- 📱 APK download (optional)

> Hosted publicly using GitHub Pages:  
👉https://Lyazi-Patrick.github.io/AutoMark-CS-Project/website/



## 🛠 Technologies Used

Tool & their Purpose
 *Flutter (Dart)* | Cross-platform mobile app development  
 *Google ML Kit* | OCR integration to extract text from image  
 *RESTful API* | Backend communication (grading + MoMo integration)  
 *MTN Mobile Money API* | Payment processing for premium features  
 *GitHub Pages* | Hosting the public website  
 *HTML/CSS* | Website frontend  

---

## 🌐 Backend & API Integration

### ✅ MTN Mobile Money API

We integrate the *MTN Mobile Money Open API* to handle secure payments inside the app. Users (lecturers/institutions) can:
- Pay to unlock bulk grading functionality
- Access downloadable student reports
- Enable long-term script storage or printing services

> Authentication tokens and callbacks are managed securely, and all requests follow standard RESTful architecture.

---

### 🔌 Sample RESTful API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /pay | Initiates a payment request (MTN API)  
| POST | /grade-script | Submits OCR results for processing and scoring  
| GET | /grades/:studentId | Fetches grading summary for a specific student  
| POST | /upload-answer-key | Stores correct answers from lecturer  


## 🚀 Getting Started (Developers)

### 1. Clone the repository
```bash
git clone https://github.com/Lyazi-Patrick/AutoMark-CS-Project
