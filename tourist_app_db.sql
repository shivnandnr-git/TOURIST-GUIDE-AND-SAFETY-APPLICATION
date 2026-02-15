-- ============================================================
--  Tourist Guide and Safety Mobile Application
--  MySQL Database Setup Script
--  Project by: Sooryadarsha C K, Revathi K, Nandana T, Shivnand NR
--  Guided by: Prof. H.A. Nisha Rose
-- ============================================================

-- Step 1: Create and select the database
CREATE DATABASE IF NOT EXISTS tourist_safety_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE tourist_safety_db;

-- ============================================================
-- MODULE 1: User Registration & Login Module
-- ============================================================

-- Stores tourist account credentials
CREATE TABLE users (
    user_id         INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(100)        NOT NULL,
    email           VARCHAR(150)        NOT NULL UNIQUE,
    phone_number    VARCHAR(20)         NOT NULL UNIQUE,
    password_hash   VARCHAR(255)        NOT NULL,       -- Store bcrypt hash, never plain text
    profile_photo   VARCHAR(255),                       -- File path or cloud URL
    nationality     VARCHAR(100),
    preferred_lang  VARCHAR(50)         DEFAULT 'en',   -- For Language Translator Module
    is_active       BOOLEAN             DEFAULT TRUE,
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Stores medical & personal details (used by SOS module)
CREATE TABLE user_medical_profiles (
    profile_id      INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL UNIQUE,
    blood_group     VARCHAR(5),                         -- e.g. A+, O-, B+
    allergies       TEXT,                               -- Comma-separated or JSON
    chronic_illness TEXT,                               -- e.g. Diabetes, Asthma
    current_meds    TEXT,                               -- Current medications
    doctor_name     VARCHAR(100),
    doctor_phone    VARCHAR(20),
    insurance_id    VARCHAR(100),
    updated_at      DATETIME            DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Stores emergency contacts (sent during SOS)
CREATE TABLE emergency_contacts (
    contact_id      INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL,
    contact_name    VARCHAR(100)        NOT NULL,
    relationship    VARCHAR(50),                        -- e.g. Father, Friend, Spouse
    phone_number    VARCHAR(20)         NOT NULL,
    email           VARCHAR(150),
    is_primary      BOOLEAN             DEFAULT FALSE,  -- Only one primary per user
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Stores JWT/session tokens for authentication (used by Django REST Framework)
CREATE TABLE auth_tokens (
    token_id        INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL,
    token           VARCHAR(500)        NOT NULL,
    device_info     VARCHAR(255),                       -- e.g. "Android 14 / Flutter"
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    expires_at      DATETIME            NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


-- ============================================================
-- MODULE 2: Location Tracking Module
-- ============================================================

-- Stores the live/last-known GPS location of each user
CREATE TABLE user_locations (
    location_id     INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL,
    latitude        DECIMAL(10, 8)      NOT NULL,
    longitude       DECIMAL(11, 8)      NOT NULL,
    accuracy_meters FLOAT,
    altitude_meters FLOAT,
    recorded_at     DATETIME            DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Stores tourist places, hospitals, police stations, restaurants etc.
CREATE TABLE nearby_places (
    place_id        INT AUTO_INCREMENT PRIMARY KEY,
    place_name      VARCHAR(200)        NOT NULL,
    place_type      ENUM(
                        'tourist_attraction',
                        'hospital',
                        'police_station',
                        'restaurant',
                        'pharmacy',
                        'hotel',
                        'other'
                    )                   NOT NULL,
    latitude        DECIMAL(10, 8)      NOT NULL,
    longitude       DECIMAL(11, 8)      NOT NULL,
    address         TEXT,
    phone_number    VARCHAR(20),
    google_place_id VARCHAR(255),                       -- From Google Maps API
    rating          DECIMAL(2, 1),                      -- e.g. 4.3
    description     TEXT,
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- MODULE 3: SOS Emergency Module
-- ============================================================

-- Logs every SOS alert triggered by a user
CREATE TABLE sos_alerts (
    sos_id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL,
    latitude        DECIMAL(10, 8)      NOT NULL,       -- Location at time of SOS
    longitude       DECIMAL(11, 8)      NOT NULL,
    triggered_at    DATETIME            DEFAULT CURRENT_TIMESTAMP,
    status          ENUM(
                        'sent',
                        'acknowledged',
                        'resolved'
                    )                   DEFAULT 'sent',
    notes           TEXT,                               -- Any extra details user added
    resolved_at     DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Tracks which contacts/authorities were notified for each SOS
CREATE TABLE sos_notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    sos_id          INT                 NOT NULL,
    contact_id      INT,                                -- NULL if sent to authorities directly
    notified_via    ENUM('sms', 'email', 'push', 'call') NOT NULL,
    sent_at         DATETIME            DEFAULT CURRENT_TIMESTAMP,
    delivery_status ENUM('sent', 'delivered', 'failed') DEFAULT 'sent',
    FOREIGN KEY (sos_id) REFERENCES sos_alerts(sos_id) ON DELETE CASCADE,
    FOREIGN KEY (contact_id) REFERENCES emergency_contacts(contact_id) ON DELETE SET NULL
);


-- ============================================================
-- MODULE 5: Language Translator Module
-- ============================================================

-- Caches translations so repeated queries don't call the API again
CREATE TABLE translation_cache (
    cache_id        INT AUTO_INCREMENT PRIMARY KEY,
    source_text     TEXT                NOT NULL,
    source_lang     VARCHAR(10)         NOT NULL,       -- e.g. 'en', 'hi', 'ml'
    target_lang     VARCHAR(10)         NOT NULL,
    translated_text TEXT                NOT NULL,
    api_provider    VARCHAR(50)         DEFAULT 'google',
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lang_pair (source_lang, target_lang)
);


-- ============================================================
-- MODULE 6: Weather Alert Module
-- ============================================================

-- Stores weather alerts fetched from Weather API per location
CREATE TABLE weather_alerts (
    alert_id        INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL,
    latitude        DECIMAL(10, 8)      NOT NULL,
    longitude       DECIMAL(11, 8)      NOT NULL,
    condition_type  ENUM(
                        'sunny',
                        'rainy',
                        'storm',
                        'flood',
                        'fog',
                        'extreme_heat',
                        'other'
                    )                   NOT NULL,
    temperature     DECIMAL(5, 2),                      -- in Celsius
    safety_tip      TEXT,                               -- e.g. "Carry raincoat"
    issued_at       DATETIME            DEFAULT CURRENT_TIMESTAMP,
    valid_until     DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


-- ============================================================
-- MODULE 7: Photo Diary Module
-- ============================================================

-- Organizes photos into trips/albums
CREATE TABLE photo_diary_albums (
    album_id        INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL,
    album_title     VARCHAR(200)        NOT NULL,       -- e.g. "Munnar Trip Jan 2026"
    description     TEXT,
    cover_photo_url VARCHAR(255),
    created_at      DATETIME            DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Stores individual photos with location and timestamp
CREATE TABLE photo_diary_entries (
    photo_id        INT AUTO_INCREMENT PRIMARY KEY,
    album_id        INT                 NOT NULL,
    user_id         INT                 NOT NULL,
    photo_url       VARCHAR(255)        NOT NULL,       -- Cloud storage URL or local path
    caption         TEXT,
    latitude        DECIMAL(10, 8),                     -- Where the photo was taken
    longitude       DECIMAL(11, 8),
    location_name   VARCHAR(200),                       -- e.g. "Athirappilly Falls"
    taken_at        DATETIME,                           -- EXIF timestamp or user input
    uploaded_at     DATETIME            DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (album_id) REFERENCES photo_diary_albums(album_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX idx_user_locations_user     ON user_locations(user_id);
CREATE INDEX idx_user_locations_time     ON user_locations(recorded_at);
CREATE INDEX idx_nearby_places_type      ON nearby_places(place_type);
CREATE INDEX idx_sos_alerts_user         ON sos_alerts(user_id);
CREATE INDEX idx_sos_alerts_status       ON sos_alerts(status);
CREATE INDEX idx_photo_entries_album     ON photo_diary_entries(album_id);
CREATE INDEX idx_photo_entries_user      ON photo_diary_entries(user_id);
CREATE INDEX idx_weather_alerts_user     ON weather_alerts(user_id);


-- ============================================================
-- SAMPLE / SEED DATA (for testing)
-- ============================================================

-- Sample user (password shown here is just a placeholder, use bcrypt in Django)
INSERT INTO users (full_name, email, phone_number, password_hash, nationality, preferred_lang)
VALUES ('Shivnand NR', 'shivnand@example.com', '9876543210', 'bcrypt_hash_here', 'Indian', 'en');

-- Sample medical profile
INSERT INTO user_medical_profiles (user_id, blood_group, allergies, chronic_illness)
VALUES (1, 'O+', 'None', 'None');

-- Sample emergency contact
INSERT INTO emergency_contacts (user_id, contact_name, relationship, phone_number, is_primary)
VALUES (1, 'Parent Name', 'Parent', '9876500000', TRUE);

-- Sample nearby places
INSERT INTO nearby_places (place_name, place_type, latitude, longitude, address, rating)
VALUES
  ('Athirappilly Falls',   'tourist_attraction', 10.2836, 76.5675, 'Athirappilly, Thrissur, Kerala', 4.7),
  ('Government Hospital',  'hospital',           10.5276, 76.2144, 'Thrissur, Kerala',               4.2),
  ('Thrissur Police Stn',  'police_station',     10.5200, 76.2100, 'Round South, Thrissur, Kerala',  4.0),
  ('Kerala Restaurant',    'restaurant',         10.5260, 76.2150, 'MG Road, Thrissur, Kerala',      4.5);

-- Sample photo album
INSERT INTO photo_diary_albums (user_id, album_title, description)
VALUES (1, 'Kerala Trip 2026', 'First tour with team');


-- ============================================================
-- USEFUL VIEWS (for Django queries / reporting)
-- ============================================================

-- View: Full user profile with medical info
CREATE VIEW v_user_full_profile AS
SELECT
    u.user_id,
    u.full_name,
    u.email,
    u.phone_number,
    u.nationality,
    u.preferred_lang,
    m.blood_group,
    m.allergies,
    m.chronic_illness,
    m.current_meds,
    m.doctor_name,
    m.doctor_phone
FROM users u
LEFT JOIN user_medical_profiles m ON u.user_id = m.user_id;

-- View: SOS alert details with user and location
CREATE VIEW v_sos_details AS
SELECT
    s.sos_id,
    u.full_name,
    u.phone_number,
    m.blood_group,
    m.allergies,
    s.latitude,
    s.longitude,
    s.triggered_at,
    s.status
FROM sos_alerts s
JOIN users u ON s.user_id = u.user_id
LEFT JOIN user_medical_profiles m ON u.user_id = m.user_id;

-- ============================================================
-- END OF SCRIPT
-- ============================================================
