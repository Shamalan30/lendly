# Lendly

### Borrow what you need. Share what you have.

Lendly is a hyperlocal community borrowing platform designed to help people borrow everyday items from people nearby instead of buying or renting them.

The idea is simple: many useful items are owned but rarely used. At the same time, someone nearby may need that exact item for only a short period of time.

Lendly connects these two people.

---

## 🌱 The Problem

People frequently purchase items that they only need occasionally.

Examples include:

* Tools
* Electronics
* Arduino and robotics kits
* Sports equipment
* Camping equipment
* Books
* Event equipment
* Household items

At the same time, many of these items remain unused for long periods.

Traditional marketplaces focus mainly on buying and selling, while rental platforms can be expensive or unavailable for smaller everyday items.

**Lendly takes a different approach: borrow from the community around you.**

---

## 💡 The Solution

Lendly creates a trusted local network where users can:

1. Search for items they need.
2. Discover available items nearby.
3. Request to borrow an item.
4. Allow the owner to approve or reject the request.
5. Complete a secure handover.
6. Record the item's condition.
7. Return the item after use.
8. Build a trusted community reputation.

Instead of asking:

> "Where can I buy this?"

Lendly encourages users to ask:

> **"Who nearby can lend me this?"**

---

## ✨ Key Features

### 🔎 I Need Something

Users can describe what they need instead of searching through endless listings.

For example:

> "I need an Arduino kit for a university project."

Lendly can then identify relevant items available nearby.

### 📍 Community Discovery

Discover items available from people within the local community.

Users can browse items based on:

* Distance
* Category
* Availability
* Item type
* Community trust

### 🤖 Smart Matching

Lendly is designed to match borrowing requests with relevant nearby items.

The matching system can consider:

* Item category
* Keywords
* Location
* Availability
* User preferences

### 🤝 Borrowing Requests

A borrower can send a request to the item owner.

The owner can:

* Accept
* Reject
* Review the request
* Arrange the handover

### 🔐 QR-Based Handover

A QR-based handover flow helps confirm the exchange between the borrower and owner.

The borrowing lifecycle can follow:

```text
Request
   ↓
Owner Approval
   ↓
Handover
   ↓
Condition Check
   ↓
Borrowing Period
   ↓
Return
   ↓
Completion
```

### ⭐ Trust & Reputation

Users can build trust through their borrowing history and community interactions.

Trust information can include:

* Ratings
* Reviews
* Successful borrowings
* Return history
* Community activity

### 📦 Condition Tracking

The condition of an item can be recorded before and after borrowing.

This helps create transparency between borrowers and owners.

### 🤖 AI Listing Assistance

AI can assist users when creating item listings by helping generate useful descriptions and organize item information.

---

## 🎯 Example Use Case

Imagine a university student needs an Arduino kit for a project.

Instead of purchasing a new kit, the student opens Lendly and selects:

**I Need Something → Arduino Kit**

Lendly identifies nearby users who have relevant equipment available.

The student sends a borrowing request.

The owner approves it.

Both users complete the QR-based handover and record the item's condition.

After the project is completed, the student returns the kit.

The transaction is completed and both users can build their reputation within the community.

---

## 🧠 Design Philosophy

Lendly follows an Apple-inspired design philosophy focused on:

* Simplicity
* Minimalism
* Spacious layouts
* Clear typography
* Smooth interactions
* Rounded UI elements
* Subtle animations
* Premium visual hierarchy

The interface uses a clean neutral foundation with refined green accents to represent:

**Community · Sustainability · Trust**

---

## 🏗️ Core Architecture

The application is designed around several main components:

```text
                 ┌─────────────────┐
                 │     Lendly      │
                 │   Mobile App    │
                 └────────┬────────┘
                          │
             ┌────────────┼────────────┐
             │            │            │
             ▼            ▼            ▼
        Authentication  Listings   Requests
             │            │            │
             └────────────┼────────────┘
                          │
                          ▼
                    Supabase
                          │
                 ┌────────┴────────┐
                 │                 │
                 ▼                 ▼
              Database          Storage
```

---

## 🛠️ Technology Stack

### Frontend

* React Native
* Expo
* TypeScript

### Backend

* Supabase
* PostgreSQL

### AI

* AI-powered matching
* AI-assisted item listing generation

### Other Technologies

* QR Code technology
* Location-based discovery
* Authentication
* Cloud storage

---

## 📱 Main Screens

The application is organized around a simple navigation structure:

```text
Home
├── Recommended Items
├── Nearby Items
└── Active Borrowings

Explore
├── Search
├── Categories
└── Nearby Listings

Add
└── Create Item Listing

Activity
├── Borrowing Requests
├── Active Borrowings
└── Returns

Profile
├── Trust Score
├── Reviews
├── Borrowing History
└── Listed Items
```

---

## 🌍 Why Lendly?

Lendly is designed around a simple idea:

> **Not everything needs to be owned.**

By encouraging people to share underused items within their communities, Lendly can help reduce unnecessary purchases while making useful resources more accessible.

The platform combines:

**Community + Technology + Trust + Sustainability**

into one borrowing experience.

---

## 🚀 Future Improvements

Potential future improvements include:

* AI-powered semantic item matching
* Advanced location-based recommendations
* Automated availability detection
* Improved trust scoring
* Identity verification
* In-app messaging
* Community groups
* Damage reporting
* Dispute management
* Smart borrowing recommendations
* Community impact statistics

---

## 📂 Project Structure

```text
lendly/
│
├── assets/
│
├── src/
│   ├── components/
│   ├── screens/
│   ├── navigation/
│   ├── services/
│   ├── models/
│   ├── utils/
│   └── theme/
│
├── README.md
├── .gitignore
├── package.json
└── ...
```

> The exact structure may differ depending on the current implementation.

---

## 🔒 Security

Do not commit sensitive information such as:

* API keys
* Supabase service-role keys
* Authentication secrets
* Private environment variables
* Passwords
* Personal user data

Use environment variables for sensitive configuration.

Example:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Never commit your `.env` file.

---

## 🧑‍💻 Project Status

**Status:** 🚧 In Development

Lendly is being developed as a prototype exploring how technology can enable hyperlocal borrowing and resource sharing.

---

## 👨‍💻 Developer

**Shamalan A/L Vellu Thavar**

BSc Artificial Intelligence (Hons)
Universiti Teknologi Malaysia Kuala Lumpur

---

## 📄 License

This project is currently intended for educational, portfolio, and prototype purposes.

A formal open-source license can be added in the future.

---

## ⭐ Vision

Lendly aims to make borrowing as easy as buying.

**Borrow what you need.
Share what you have.
Build a better community.**
