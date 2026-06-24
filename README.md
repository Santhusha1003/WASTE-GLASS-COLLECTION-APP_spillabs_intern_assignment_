# Waste Glass Collection App

Mobile Intern Technical Assignment

## Technologies

### Frontend

* Flutter

### Backend

* .NET Web API (.NET 8)

### Database

* SQLite

### Hosting

* Render Cloud Platform

---

## Features

* Supplier route management
* Barcode scanning
* Offline collection saving
* Trip report generation
* Data synchronization
* Route optimization using Dijkstra Algorithm
* Distance calculation using Haversine Formula
* Supplier status tracking (Pending / Next / Collected)
* Real-time collection updates
* Shortfall quantity warnings
* Admin route management
* Route scheduling for different dates
* Hosted REST API backend
* Offline-first mobile experience
* Local SQLite data persistence
* Collection history tracking

---

## Project Architecture

### Mobile Application

The Flutter application is used by waste glass collectors to:

* View assigned collection routes
* Scan supplier barcodes
* Record collected glass quantities
* Track collection progress
* Generate trip reports
* Synchronize data with the backend

### Backend API

The ASP.NET Core backend provides:

* Route management
* Supplier management
* Collection record management
* Trip report generation
* Route optimization
* Status management
* Data synchronization

### Database Design

The SQLite database stores:

* Supplier details
* GPS coordinates
* Barcode references
* Route information
* Collection records
* Expected quantities
* Collection statuses

---

## Route Optimization

The application uses:

### Haversine Formula

Used to calculate the distance between GPS coordinates.

### Dijkstra Algorithm

Used to determine the optimal supplier collection route and minimize travel distance.

---

## Offline First Functionality

The application continues to work without an internet connection.

Collection records are saved locally using SQLite and can later be synchronized with the hosted backend using the Sync to Server feature.

---

## Hosted Backend

### Swagger Documentation

https://waste-glass-collection-app-spillabs.onrender.com/swagger/index.html

### Admin Dashboard

https://waste-glass-collection-app-spillabs.onrender.com/admin/index.html

The backend is deployed on Render and is publicly accessible for evaluation. The mobile application communicates directly with the hosted API instead of using localhost, allowing the system to work from any Android device connected to the internet.

---

## Implemented Screens

### Screen 1 – Trip Sequence

* Display supplier route sequence
* Show route distance
* Show remaining stops
* Display supplier status

### Screen 2 – Scan & Collect

* Barcode verification
* Supplier validation
* Collection quantity entry
* Collection submission

### Screen 3 – Trip Report

* Collection summary
* Total collected quantity
* Route distance
* Trip duration
* Shortfall warnings
* Sync to server

---

## Setup Instructions

### Flutter Frontend

```bash
flutter pub get
flutter run
```

### Backend API

```bash
cd BackendAPI/WasteGlassAPI
dotnet restore
dotnet run
```

---

## GitHub Repository

https://github.com/Santhusha1003/WASTE-GLASS-COLLECTION-APP_spillabs_intern_assignment_

---

## Author

Santhusha Manjalee

Mobile Intern Technical Assignment Submission
