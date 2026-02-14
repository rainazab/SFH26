# 🚀 BOTTLE APP - BACKEND IMPLEMENTATION PLAN
## SF Hacks 2026 - Full-Stack Implementation

---

## ✅ COMPLETED (Phase 1-2)

### Configuration & Models
- [x] `Config.swift` - Environment variable management
- [x] `.env.example` - Template for API keys
- [x] `.gitignore` - Protect sensitive files
- [x] `Models.swift` - MongoDB-compatible models with GeoJSON support

---

## 🔄 IN PROGRESS - CRITICAL PATH

### Next Priority: MongoDB Service (2-3 hours)
Create `Services/MongoDBService.swift` with:
- Geospatial queries for nearby jobs
- Job CRUD operations
- User profile management
- Claims tracking
- Impact stats updates

### Then: Authentication (2-3 hours)
Create `Services/AuthService.swift` with:
- Firebase Auth integration
- Sign up/Sign in/Sign out
- User profile creation in MongoDB
- Session management

---

## 📦 REQUIRED DEPENDENCIES

### Add via Swift Package Manager:

1. **Firebase iOS SDK** (v10.20.0+)
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
   Select: FirebaseAuth, FirebaseFirestore, FirebaseStorage, FirebaseMessaging

2. **Google AI SDK** (for Gemini)
   ```
   https://github.com/google/generative-ai-swift
   ```

### Manual Setup Required:
- Download `GoogleService-Info.plist` from Firebase Console
- Add to Xcode project root
- Enable Email/Password auth in Firebase Console
- Create MongoDB Atlas cluster (M0 free tier)
- Enable MongoDB Data API
- Create Gemini API key at ai.google.dev

---

## 🗄️ MONGODB SCHEMA

### Collections to Create:

**1. users**
```json
{
  "_id": "string (Firebase UID)",
  "name": "string",
  "email": "string",
  "type": "collector|donor",
  "rating": 5.0,
  "total_bottles": 0,
  "total_earnings": 0.0,
  "join_date": ISODate,
  "badges": [],
  "fcm_token": "string"
}
```

**2. jobs** (needs 2dsphere index!)
```json
{
  "_id": "ObjectId",
  "donor_id": "string",
  "title": "string",
  "location": {
    "type": "Point",
    "coordinates": [longitude, latitude]
  },
  "address": "string",
  "bottle_count": 50,
  "payout": 5.0,
  "tier": "residential|bulk|commercial",
  "status": "available|claimed|completed",
  "schedule": "string",
  "notes": "string",
  "donor_rating": 4.8,
  "is_recurring": false,
  "available_time": "string",
  "claimed_by": "string",
  "created_at": ISODate
}
```

**Index to create:**
```javascript
db.jobs.createIndex({ location: "2dsphere" })
```

**3. claims**
```json
{
  "_id": "ObjectId",
  "job_id": "ObjectId",
  "collector_id": "string",
  "donor_id": "string",
  "status": "pending|completed|disputed",
  "claimed_at": ISODate,
  "completed_at": ISODate,
  "bottles_collected": 50,
  "ai_verified_count": 48,
  "earnings": 5.0,
  "collector_rating": 5.0,
  "donor_rating": 5.0,
  "photo_url": "string"
}
```

**4. impact_stats**
```json
{
  "_id": "string (user_id)",
  "total_bottles": 450,
  "total_earnings": 45.0,
  "co2_saved": 20.25,
  "trees_equivalent": 1,
  "days_car_removed": 2,
  "days_home_powered": 5,
  "rank_percentile": 15
}
```

---

## 🔑 API KEYS NEEDED

### MongoDB Atlas:
1. Create free M0 cluster at https://cloud.mongodb.com/
2. Go to Data API → Create API Key
3. Note down: App ID, API Key, Cluster URL

### Firebase:
1. Create project at https://console.firebase.google.com/
2. Add iOS app with bundle ID: `rz.Bottle`
3. Download GoogleService-Info.plist
4. Enable Authentication → Email/Password
5. Enable Storage → Start in test mode

### Gemini AI:
1. Go to https://aistudio.google.com/app/apikey
2. Create API key
3. Copy key to .env

### Google Maps:
1. Go to https://console.cloud.google.com/
2. Enable Geocoding API
3. Create API key
4. Copy to .env

---

## 📱 IMPLEMENTATION PRIORITY

### CRITICAL (Must-Have for Demo):
1. ✅ Models with GeoJSON support
2. ⏳ MongoDB geospatial queries
3. ⏳ Authentication (sign up/in)
4. ⏳ Fetch nearby jobs on map
5. ⏳ Claim job functionality
6. ⏳ Post new job (donors)

### IMPORTANT (Hackathon Tracks):
7. ⏳ Gemini AI bottle counting
8. ⏳ Photo upload to Firebase Storage
9. ⏳ CO₂ impact calculations
10. ⏳ Real-time job updates

### NICE-TO-HAVE (Polish):
11. ⏳ Push notifications
12. ⏳ Offline caching
13. ⏳ Location tracking
14. ⏳ Analytics
15. ⏳ Debug menu

---

## ⏱️ TIME ESTIMATES

### Minimum Viable Backend (8 hours):
- MongoDB Service: 3h
- Auth Service: 2h
- Integration into existing views: 2h
- Testing & debugging: 1h

### Full Implementation (21 hours):
- Core backend: 8h
- Gemini AI: 3h
- Firebase Storage: 2h
- Location Services: 2h
- Real-time updates: 2h
- Impact tracking: 2h
- Polish & testing: 2h

---

## 🎯 HACKATHON STRATEGY

### Day 1 (8 hours):
- ✅ Setup & Models (Done!)
- MongoDB Service
- Auth Service
- Basic integration

### Day 2 (8 hours):
- Gemini AI integration
- Photo upload
- Complete claim flow
- Impact calculations

### Day 3 (5 hours):
- Testing
- Demo data generation
- Bug fixes
- Demo preparation

---

## 🚨 CRITICAL NOTES

### MongoDB Coordinates:
**VERY IMPORTANT:** MongoDB uses [longitude, latitude] order, NOT [latitude, longitude]!
```swift
// CORRECT:
GeoLocation(longitude: -122.4194, latitude: 37.7749)
// coordinates = [-122.4194, 37.7749]

// WRONG:
// coordinates = [37.7749, -122.4194]  // Will break geospatial queries!
```

### Firebase Setup:
- GoogleService-Info.plist MUST be in project root
- Bundle ID must match Firebase iOS app
- Enable Email/Password in Authentication settings

### Gemini Rate Limits:
- Free tier: 60 requests/minute
- Add throttling/retry logic
- Cache results when possible

---

## 📞 TROUBLESHOOTING

### "Could not connect to MongoDB"
- Check MONGO_API_KEY is correct
- Verify Data API is enabled in Atlas
- Check network connectivity

### "Firebase not initialized"
- Ensure GoogleService-Info.plist is added
- Clean build folder (Cmd+Shift+K)
- Restart Xcode

### "Location services disabled"
- Add NSLocationWhenInUseUsageDescription to Info.plist
- Request permission in LocationService

### "Gemini API error"
- Check API key is valid
- Verify you haven't hit rate limit
- Ensure image is properly formatted

---

## ✅ NEXT STEPS

1. **Install Dependencies** (30 min)
   - Add Firebase via SPM
   - Add Google AI SDK via SPM
   - Add GoogleService-Info.plist

2. **Create MongoDB Service** (3 hours)
   - Implement geospatial queries
   - Add CRUD operations
   - Test with Postman/Bruno

3. **Create Auth Service** (2 hours)
   - Implement sign up/in/out
   - Connect to MongoDB
   - Update UI flows

4. **Integration** (2 hours)
   - Update MapView to fetch real data
   - Update JobDetailView to claim jobs
   - Update DonorHomeView to post jobs

---

**STATUS:** Foundation complete! Ready for MongoDB + Auth implementation.

**ESTIMATED COMPLETION:** 8-10 hours of focused work for MVP, 21 hours for full implementation.

Let me know when you're ready to continue with the next phase! 🚀
