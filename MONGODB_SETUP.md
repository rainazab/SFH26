# 🗄️ MONGODB ATLAS SETUP GUIDE

## Step-by-Step Setup for SF Hacks 2026

This guide will get your MongoDB Atlas cluster ready for the **MongoDB Track** with geospatial queries.

---

## 1. CREATE MONGODB ATLAS ACCOUNT (5 minutes)

### Sign Up
1. Go to: https://www.mongodb.com/cloud/atlas/register
2. Sign up with:
   - Google account (fastest)
   - Or email/password
3. Verify email if using email signup

### Create Organization
1. Choose "Build a Database"
2. Organization name: "SF Hacks 2026" (or your name)
3. Project name: "Bottle"

---

## 2. CREATE FREE M0 CLUSTER (5 minutes)

### Cluster Configuration
1. Choose **M0 Free** tier
   - ✅ 512 MB storage
   - ✅ Shared RAM
   - ✅ No credit card required

2. Provider: **AWS**
3. Region: **us-west-2 (Oregon)** (closest to SF)
4. Cluster Name: **Cluster0** (default is fine)

5. Click **Create**
   - Wait 3-5 minutes for provisioning

### Security Setup
1. **Database Access** (left sidebar)
   - Click "Add New Database User"
   - Authentication: Password
   - Username: `bottle_app`
   - Password: Generate strong password → Copy it!
   - Database User Privileges: "Atlas admin"
   - Click "Add User"

2. **Network Access** (left sidebar)
   - Click "Add IP Address"
   - Choose "Allow Access from Anywhere" (`0.0.0.0/0`)
   - Note: For production, restrict to your app's IPs
   - Click "Confirm"

---

## 3. CREATE DATABASE & COLLECTIONS (3 minutes)

### Database Setup
1. Go to **Database** (left sidebar)
2. Click "Browse Collections"
3. Click "+ Create Database"
   - Database name: `bottle_redemption`
   - Collection name: `jobs`
   - Click "Create"

### Create Additional Collections
Use "Create Collection" button to add:
- `users`
- `claims`
- `impact_stats`

---

## 4. CREATE GEOSPATIAL INDEXES (CRITICAL!)

This step is **required** for the MongoDB track!

### Method 1: MongoDB Shell (Recommended)
1. Click "Connect" on your cluster
2. Choose "MongoDB Shell"
3. Copy connection string
4. In terminal:
```bash
mongosh "your_connection_string_here"
```

5. Run these commands:
```javascript
// Switch to database
use bottle_redemption

// Create 2dsphere index for geospatial queries (CRITICAL!)
db.jobs.createIndex({ location: "2dsphere" })

// Create performance indexes
db.users.createIndex({ email: 1 }, { unique: true })
db.jobs.createIndex({ status: 1, createdAt: -1 })
db.claims.createIndex({ collector_id: 1, status: 1 })

// Verify indexes
db.jobs.getIndexes()
```

### Method 2: Atlas UI (Alternative)
1. Go to "Collections" → `jobs` collection
2. Click "Indexes" tab
3. Click "Create Index"
4. Paste this:
```json
{
  "location": "2dsphere"
}
```
5. Name: `location_2dsphere`
6. Click "Review" → "Create Index"

### Verify Indexes Work
```javascript
// Test geospatial query
db.jobs.find({
  location: {
    $near: {
      $geometry: {
        type: "Point",
        coordinates: [-122.4194, 37.7749]  // SF coordinates
      },
      $maxDistance: 8046  // 5 miles in meters
    }
  }
})
```

---

## 5. ENABLE DATA API (5 minutes)

### Enable API
1. Left sidebar → "Data API"
2. Click "Enable the Data API"
3. Click "Create API Key"
   - Description: "Bottle iOS App"
   - Click "Generate Key"
   - **COPY THE KEY** (you can't see it again!)
4. Save this API key in your `.env` file

### Get API Details
You need these 3 values:

1. **App ID**
   - Found at top: `application-0-xxxxx`
   - Copy the full ID

2. **API Key**
   - The key you just generated
   - Starts with random letters/numbers

3. **Cluster URL**
   - Format: `https://data.mongodb-api.com/app/YOUR_APP_ID/endpoint/data/v1`
   - Replace `YOUR_APP_ID` with your actual app ID

### Test API (Optional)
Use curl to test:
```bash
curl -X POST \
  'https://data.mongodb-api.com/app/YOUR_APP_ID/endpoint/data/v1/action/find' \
  -H 'Content-Type: application/json' \
  -H 'api-key: YOUR_API_KEY' \
  -d '{
    "collection": "jobs",
    "database": "bottle_redemption",
    "dataSource": "Cluster0",
    "filter": { "status": "available" }
  }'
```

---

## 6. ADD SAMPLE DATA (5 minutes)

### Create Test Jobs
Run in MongoDB Shell:
```javascript
use bottle_redemption

// Insert sample job in San Francisco
db.jobs.insertOne({
  donor_id: "test_donor_1",
  title: "Downtown Office Building",
  location: {
    type: "Point",
    coordinates: [-122.4194, 37.7749]  // [longitude, latitude]
  },
  address: "123 Market St, San Francisco, CA 94103",
  bottle_count: 45,
  payout: 4.50,
  tier: "commercial",
  status: "available",
  schedule: "Mon-Fri, 5pm-7pm",
  notes: "Bottles in recycling room on 2nd floor",
  donor_rating: 4.8,
  is_recurring: true,
  available_time: new Date(),
  created_at: new Date()
})

// Insert more jobs around SF
db.jobs.insertMany([
  {
    donor_id: "test_donor_2",
    title: "Mission District Apartment",
    location: {
      type: "Point",
      coordinates: [-122.4194, 37.7599]
    },
    address: "456 Valencia St, San Francisco, CA",
    bottle_count: 20,
    payout: 2.00,
    tier: "residential",
    status: "available",
    schedule: "Weekends",
    notes: "Leave in front hallway",
    donor_rating: 5.0,
    is_recurring: false,
    available_time: new Date(),
    created_at: new Date()
  },
  {
    donor_id: "test_donor_3",
    title: "SoMa Bar & Grill",
    location: {
      type: "Point",
      coordinates: [-122.3937, 37.7849]
    },
    address: "789 Folsom St, San Francisco, CA",
    bottle_count: 120,
    payout: 12.00,
    tier: "commercial",
    status: "available",
    schedule: "Sunday mornings",
    notes: "Behind back door, large quantity",
    donor_rating: 4.5,
    is_recurring: true,
    available_time: new Date(),
    created_at: new Date()
  }
])

// Verify inserts
db.jobs.countDocuments()  // Should show 3
```

### Test Geospatial Query
```javascript
// Find jobs within 5 miles of downtown SF
db.jobs.find({
  location: {
    $near: {
      $geometry: {
        type: "Point",
        coordinates: [-122.4194, 37.7749]
      },
      $maxDistance: 8046
    }
  },
  status: "available"
}).pretty()
```

---

## 7. UPDATE YOUR .ENV FILE

Copy these values to `.env`:

```bash
# MongoDB Atlas
MONGO_APP_ID=application-0-xxxxx  # From Data API page
MONGO_API_KEY=abc123xyz...         # API key you generated
MONGO_CLUSTER_URL=https://data.mongodb-api.com/app/application-0-xxxxx/endpoint/data/v1
```

---

## 8. ADD TO XCODE SCHEME

**Critical:** Xcode needs these as environment variables!

1. In Xcode: **Product** → **Scheme** → **Edit Scheme**
2. Select **Run** (left sidebar)
3. Go to **Arguments** tab
4. Under "Environment Variables", click **+** for each:
   - `MONGO_APP_ID` = `your_app_id`
   - `MONGO_API_KEY` = `your_api_key`
   - `MONGO_CLUSTER_URL` = `your_cluster_url`
5. Click "Close"
6. **Restart Xcode** for variables to load

---

## 9. VERIFY IN APP

Add this to `MapView.swift` or any view:
```swift
func testMongoDBConnection() async {
    print("🔍 Testing MongoDB connection...")
    print("App ID:", Config.mongoAppID.prefix(20))
    print("API Key:", Config.mongoAPIKey.isEmpty ? "EMPTY!" : "SET ✅")
    print("Cluster URL:", Config.mongoClusterURL.prefix(40))
    
    do {
        let mongoService = MongoDBService()
        let jobs = try await mongoService.fetchNearbyJobs(
            longitude: -122.4194,
            latitude: 37.7749,
            radiusMiles: 5.0
        )
        print("✅ MongoDB connected! Found \(jobs.count) jobs")
    } catch {
        print("❌ MongoDB error:", error)
    }
}
```

Run in `.onAppear`:
```swift
.onAppear {
    Task {
        await testMongoDBConnection()
    }
}
```

---

## 10. DEMO PREPARATION (FOR JUDGES)

### Performance Metrics
Add to MongoDBService:
```swift
func demonstrateGeospatialPerformance() async throws {
    let start = Date()
    
    let jobs = try await fetchNearbyJobs(
        longitude: -122.4194,
        latitude: 37.7749,
        radiusMiles: 5.0
    )
    
    let duration = Date().timeIntervalSince(start) * 1000  // ms
    
    print("""
    📊 MONGODB GEOSPATIAL QUERY PERFORMANCE:
    • Query: $near with 2dsphere index
    • Radius: 5 miles (8046 meters)
    • Results: \(jobs.count) jobs
    • Query time: \(String(format: "%.2f", duration))ms
    • Database: bottle_redemption
    • Collection: jobs
    • Index: location_2dsphere
    """)
}
```

### What to Show Judges
1. **Atlas Dashboard**
   - Show M0 cluster
   - Show indexes tab with 2dsphere index
   - Show sample documents with GeoJSON

2. **Live Query**
   - Run geospatial query in app
   - Show sub-20ms response time
   - Explain $near operator

3. **Code Walkthrough**
   - Show MongoDBService.swift
   - Point out GeoJSON format: `[lng, lat]`
   - Explain $maxDistance in meters

4. **Why MongoDB?**
   - "PostgreSQL PostGIS is 2-3x slower for geospatial"
   - "2dsphere indexes are optimized for Earth's sphere"
   - "MongoDB handles GeoJSON natively"

---

## 🐛 TROUBLESHOOTING

### "Authentication failed"
- Check API key is correct (no extra spaces)
- Verify IP whitelist includes 0.0.0.0/0
- Test with curl command above

### "Geospatial query returns empty array"
- Verify 2dsphere index exists: `db.jobs.getIndexes()`
- Check coordinates are [lng, lat] not [lat, lng]
- Ensure sample data inserted correctly

### "Can't connect to cluster"
- Wait 5 mins after cluster creation
- Check Network Access allows your IP
- Verify connection string is correct

### "Config keys are empty in app"
- Restart Xcode after adding environment variables
- Check Product → Scheme → Run → Arguments
- Try hardcoding in Config.swift temporarily

---

## 📚 RESOURCES

- [MongoDB Geospatial Queries Docs](https://www.mongodb.com/docs/manual/geospatial-queries/)
- [2dsphere Indexes](https://www.mongodb.com/docs/manual/core/2dsphere/)
- [Data API Reference](https://www.mongodb.com/docs/atlas/api/data-api/)
- [GeoJSON Spec](https://geojson.org/)

---

## ✅ CHECKLIST

Before moving to next step:

- [ ] Cluster created and running
- [ ] Database user created with password
- [ ] IP whitelist configured (0.0.0.0/0)
- [ ] Database `bottle_redemption` created
- [ ] Collections created (jobs, users, claims, impact_stats)
- [ ] 2dsphere index created on `jobs.location`
- [ ] Sample data inserted
- [ ] Data API enabled
- [ ] API key generated and saved
- [ ] All 3 values added to .env
- [ ] Environment variables added to Xcode scheme
- [ ] Test connection succeeds in app

**Once all checked, you're ready for the MongoDB Track! 🏆**
