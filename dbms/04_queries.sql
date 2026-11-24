-- StageSync: SQL Queries
--
-- Runs against the schema in 03_schema.sql.
-- The file is organized into four parts:
--   Part 1  Sample data for all 23 tables.
--   Part 2  Queries used by the backend application (marked -- READ or -- WRITE).
--   Part 3  Core algorithm queries (artist matching, booking conflict, setlist duration).
--   Part 4  Reports, aggregations, window functions, and integrity checks.
--
-- Run with:
--   psql -v ON_ERROR_STOP=1 -f 03_schema.sql  <database>
--   psql -v ON_ERROR_STOP=1 -f 04_queries.sql <database>

SET search_path TO stagesync;

-- ----------------------------------------------------------------------------
-- Part 1: Sample data
-- ----------------------------------------------------------------------------

BEGIN;

TRUNCATE users, artist_profiles, genres, skills, instruments, artist_genres,
         artist_skills, bands, band_members, venues, venue_availabilities,
         equipment, equipment_reservations, events, event_requirements,
         bookings, songs, band_songs, setlists, setlist_songs, rehearsals,
         rehearsal_participants, rehearsal_songs
RESTART IDENTITY CASCADE;

-- Reference data
INSERT INTO genres (id, name) VALUES
    (1, 'Rock'),
    (2, 'Jazz'),
    (3, 'Electronic'),
    (4, 'Pop'),
    (5, 'Classical'),
    (6, 'Blues');

INSERT INTO skills (id, name, category) VALUES
    (1, 'Electric Guitar',        'Instrumental'),
    (2, 'Lead Vocals',            'Vocal'),
    (3, 'Drumming',               'Instrumental'),
    (4, 'Bass Guitar',            'Instrumental'),
    (5, 'DJ Mixing',              'Performance'),
    (6, 'Live Sound Engineering', 'Technical');

INSERT INTO instruments (id, name) VALUES
    (1, 'Fender Stratocaster Electric Guitar'),
    (2, 'Yamaha Stage Custom Drum Kit'),
    (3, 'Fender Jazz Bass Guitar'),
    (4, 'Roland Stage Piano');

-- Users
INSERT INTO users (id, email, password_hash, first_name, last_name, role) VALUES
    ('11111111-1111-1111-1111-111111111101', 'admin@stagesync.io',        '$2a$12$hash1', 'Vikram', 'Malhotra', 'ADMIN'),
    ('11111111-1111-1111-1111-111111111102', 'maya@soundwave.com',        '$2a$12$hash2', 'Maya',   'Sengupta', 'ORGANIZER'),
    ('11111111-1111-1111-1111-111111111103', 'aarav.guitar@gmail.com',    '$2a$12$hash3', 'Aarav',  'Sharma',   'ARTIST'),
    ('11111111-1111-1111-1111-111111111104', 'meera.vox@gmail.com',       '$2a$12$hash4', 'Meera',  'Kapoor',   'ARTIST'),
    ('11111111-1111-1111-1111-111111111105', 'kabir.drums@gmail.com',     '$2a$12$hash5', 'Kabir',  'Verma',    'ARTIST'),
    ('11111111-1111-1111-1111-111111111106', 'ananya.bass@gmail.com',     '$2a$12$hash6', 'Ananya', 'Iyer',     'ARTIST'),
    ('11111111-1111-1111-1111-111111111107', 'neha.sound@acoustics.com',  '$2a$12$hash7', 'Neha',   'Patel',    'ARTIST'),
    ('11111111-1111-1111-1111-111111111108', 'suresh@grandhall.com',      '$2a$12$hash8', 'Suresh', 'Reddy',    'ORGANIZER');

-- Artist profiles
INSERT INTO artist_profiles (id, user_id, stage_name, bio, professional_type, experience_years, hourly_rate, city) VALUES
    ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111103', 'Aarav Strings', 'Rock and blues guitarist with live stage experience.', 'MUSICIAN',       8, 3500.00, 'Mumbai'),
    ('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111104', 'Meera K',       'Vocalist trained in pop and jazz.',                  'SINGER',         6, 4000.00, 'Mumbai'),
    ('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111105', 'Kabir Beats',   'Rock drummer with studio and live experience.',      'MUSICIAN',       5, 3000.00, 'Mumbai'),
    ('22222222-2222-2222-2222-222222222204', '11111111-1111-1111-1111-111111111106', 'Ana Bass',      'Bassist specializing in jazz and funk.',              'MUSICIAN',       4, 2800.00, 'Bengaluru'),
    ('22222222-2222-2222-2222-222222222205', '11111111-1111-1111-1111-111111111107', 'Neha Sound',    'Live sound engineer for events and concerts.',        'SOUND_ENGINEER', 9, 4500.00, 'Mumbai');

-- Artist qualifications
INSERT INTO artist_genres (artist_id, genre_id) VALUES
    ('22222222-2222-2222-2222-222222222201', 1),
    ('22222222-2222-2222-2222-222222222201', 6),
    ('22222222-2222-2222-2222-222222222202', 2),
    ('22222222-2222-2222-2222-222222222202', 4),
    ('22222222-2222-2222-2222-222222222203', 1),
    ('22222222-2222-2222-2222-222222222204', 2);

INSERT INTO artist_skills (artist_id, skill_id, proficiency) VALUES
    ('22222222-2222-2222-2222-222222222201', 1, 'EXPERT'),
    ('22222222-2222-2222-2222-222222222202', 2, 'EXPERT'),
    ('22222222-2222-2222-2222-222222222203', 3, 'ADVANCED'),
    ('22222222-2222-2222-2222-222222222204', 4, 'ADVANCED'),
    ('22222222-2222-2222-2222-222222222205', 6, 'EXPERT');

-- Bands and members
INSERT INTO bands (id, name, formed_date, bio, genre_id, created_by) VALUES
    ('33333333-3333-3333-3333-333333333301', 'Chrysalis', '2022-01-10', 'Four-member alternative rock band from Mumbai.', 1, '11111111-1111-1111-1111-111111111103');

INSERT INTO band_members (id, band_id, artist_id, role, instrument_id, joined_date) VALUES
    ('44444444-4444-4444-4444-444444444401', '33333333-3333-3333-3333-333333333301', '22222222-2222-2222-2222-222222222201', 'Lead Guitarist', 1, '2022-01-10'),
    ('44444444-4444-4444-4444-444444444402', '33333333-3333-3333-3333-333333333301', '22222222-2222-2222-2222-222222222202', 'Vocalist',       NULL, '2022-02-01'),
    ('44444444-4444-4444-4444-444444444403', '33333333-3333-3333-3333-333333333301', '22222222-2222-2222-2222-222222222203', 'Drummer',        2, '2022-02-15');

-- Venues and availabilities
INSERT INTO venues (id, name, address, city, capacity, hourly_rate, description, facilities, owner_id) VALUES
    ('55555555-5555-5555-5555-555555555501', 'Grand Blue Note Hall', '42 Bandra West', 'Mumbai',    600, 8000.00, 'Auditorium with stage and sound system.', ARRAY['Green Room', 'PA System', 'Lighting'], '11111111-1111-1111-1111-111111111108'),
    ('55555555-5555-5555-5555-555555555502', 'Echo Arena',           '12 Koramangala', 'Bengaluru', 900, 12000.00, 'Open-air venue for live concerts.',       ARRAY['Green Room', 'VIP Lounge'],             '11111111-1111-1111-1111-111111111108');

INSERT INTO venue_availabilities (id, venue_id, day_of_week, open_time, close_time) VALUES
    ('66666666-6666-6666-6666-666666666601', '55555555-5555-5555-5555-555555555501', 5, '10:00:00', '23:00:00'),
    ('66666666-6666-6666-6666-666666666602', '55555555-5555-5555-5555-555555555501', 6, '10:00:00', '23:30:00');

-- Equipment
INSERT INTO equipment (id, name, category, total_quantity, condition, owner_id, daily_rate) VALUES
    ('77777777-7777-7777-7777-777777777701', 'Wireless Vocal Mic', 'MICROPHONE', 6, 'GOOD', '11111111-1111-1111-1111-111111111108', 1000.00),
    ('77777777-7777-7777-7777-777777777702', 'Guitar Amplifier',   'AMPLIFIER',  3, 'GOOD', '11111111-1111-1111-1111-111111111108', 2000.00),
    ('77777777-7777-7777-7777-777777777703', '16-Channel Mixer',   'MIXER',      2, 'GOOD', '11111111-1111-1111-1111-111111111108', 3500.00);

-- Events and requirements
INSERT INTO events (id, title, description, event_type, genre_id, venue_id, organizer_id, start_time, end_time, performance_duration_minutes, status, budget) VALUES
    ('88888888-8888-8888-8888-888888888801', 'Monsoon Rock Fest', 'Live rock concert in Mumbai.', 'CONCERT', 1, '55555555-5555-5555-5555-555555555501', '11111111-1111-1111-1111-111111111102',
     '2026-11-20 18:00:00+05:30', '2026-11-20 22:00:00+05:30', 90, 'CONFIRMED', 150000.00),
    ('88888888-8888-8888-8888-888888888802', 'Jazz Night',        'Acoustic jazz evening.',       'CONCERT', 2, '55555555-5555-5555-5555-555555555501', '11111111-1111-1111-1111-111111111102',
     '2026-11-21 19:00:00+05:30', '2026-11-21 21:30:00+05:30', 60, 'PUBLISHED', 80000.00);

INSERT INTO event_requirements (id, event_id, skill_id, genre_id, min_experience_years, professional_type, quantity) VALUES
    ('88888888-8888-8888-8888-888888888811', '88888888-8888-8888-8888-888888888801', 1, 1, 5, 'MUSICIAN',       1),
    ('88888888-8888-8888-8888-888888888812', '88888888-8888-8888-8888-888888888801', 6, 1, 5, 'SOUND_ENGINEER', 1);

-- Bookings
INSERT INTO bookings (id, event_id, artist_id, band_id, venue_id, start_time, end_time, status, fee, created_by) VALUES
    ('99999999-9999-9999-9999-999999999901', '88888888-8888-8888-8888-888888888801', NULL, '33333333-3333-3333-3333-333333333301', NULL,
     '2026-11-20 19:00:00+05:30', '2026-11-20 21:00:00+05:30', 'CONFIRMED', 40000.00, '11111111-1111-1111-1111-111111111102'),
    ('99999999-9999-9999-9999-999999999902', '88888888-8888-8888-8888-888888888801', '22222222-2222-2222-2222-222222222205', NULL, NULL,
     '2026-11-20 17:30:00+05:30', '2026-11-20 22:30:00+05:30', 'CONFIRMED', 15000.00, '11111111-1111-1111-1111-111111111102'),
    ('99999999-9999-9999-9999-999999999903', '88888888-8888-8888-8888-888888888802', '22222222-2222-2222-2222-222222222202', NULL, NULL,
     '2026-11-21 19:30:00+05:30', '2026-11-21 21:00:00+05:30', 'PENDING',   12000.00, '11111111-1111-1111-1111-111111111102');

-- Equipment reservations
INSERT INTO equipment_reservations (id, equipment_id, event_id, quantity, start_time, end_time, status) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '77777777-7777-7777-7777-777777777701', '88888888-8888-8888-8888-888888888801', 3,
     '2026-11-20 17:00:00+05:30', '2026-11-20 22:30:00+05:30', 'RESERVED');

-- Songs and band songs
INSERT INTO songs (id, title, artist_name, duration_seconds, genre_id, created_by) VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'Horizon Echoes', 'Chrysalis', 300, 1, '11111111-1111-1111-1111-111111111103'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'Midnight Drift', 'Chrysalis', 240, 1, '11111111-1111-1111-1111-111111111103'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3', 'Cobalt Sky',     'Chrysalis', 260, 1, '11111111-1111-1111-1111-111111111103');

INSERT INTO band_songs (band_id, song_id) VALUES
    ('33333333-3333-3333-3333-333333333301', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1'),
    ('33333333-3333-3333-3333-333333333301', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'),
    ('33333333-3333-3333-3333-333333333301', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3');

-- Setlists and setlist songs
INSERT INTO setlists (id, name, event_id, booking_id, target_duration_seconds, created_by) VALUES
    ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'Chrysalis Main Set', '88888888-8888-8888-8888-888888888801', '99999999-9999-9999-9999-999999999901', 900, '11111111-1111-1111-1111-111111111103');

INSERT INTO setlist_songs (id, setlist_id, song_id, position) VALUES
    ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 1),
    ('dddddddd-dddd-dddd-dddd-ddddddddddd2', 'cccccccc-cccc-cccc-cccc-ccccccccccc1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 2);

-- Rehearsals
INSERT INTO rehearsals (id, band_id, event_id, venue_id, start_time, end_time, notes, created_by) VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', '33333333-3333-3333-3333-333333333301', '88888888-8888-8888-8888-888888888801', '55555555-5555-5555-5555-555555555501',
     '2026-11-19 15:00:00+05:30', '2026-11-19 17:00:00+05:30', 'Soundcheck rehearsal', '11111111-1111-1111-1111-111111111103');

INSERT INTO rehearsal_participants (rehearsal_id, artist_id, confirmed) VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', '22222222-2222-2222-2222-222222222201', true),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', '22222222-2222-2222-2222-222222222202', true);

INSERT INTO rehearsal_songs (rehearsal_id, song_id) VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1');

COMMIT;


-- ----------------------------------------------------------------------------
-- Part 2: Queries the application runs
-- ----------------------------------------------------------------------------

-- 2.1 User login: Find user credentials by email
--     src/services/auth.service.js, login
-- READ
SELECT id, email, password_hash, role
FROM users
WHERE email = 'maya@soundwave.com';

-- 2.2 User registration: Create new user account
--     src/services/auth.service.js, register
-- WRITE
INSERT INTO users (id, email, password_hash, first_name, last_name, role)
VALUES (gen_random_uuid(), 'karan@music.com', '$2a$12$sample', 'Karan', 'Shah', 'ARTIST')
RETURNING id, email, first_name, last_name, role;

-- 2.3 User profile: Fetch user details along with artist profile
--     src/services/user.service.js, getUserById
-- READ
SELECT u.id, u.email, u.first_name, u.last_name, u.role,
       ap.stage_name, ap.professional_type, ap.hourly_rate, ap.city
FROM users u
LEFT JOIN artist_profiles ap ON ap.user_id = u.id
WHERE u.id = '11111111-1111-1111-1111-111111111103';

-- 2.4 Search artists: Filter by city, minimum experience, and genre
--     src/services/artist.service.js, searchArtists
-- READ
SELECT ap.id, ap.stage_name, ap.professional_type, ap.experience_years, ap.hourly_rate,
       g.name AS genre_name
FROM artist_profiles ap
JOIN artist_genres ag ON ag.artist_id = ap.id
JOIN genres g ON g.id = ag.genre_id
WHERE ap.city = 'Mumbai'
  AND ap.experience_years >= 5;

-- 2.5 Update artist profile: Change hourly rate and availability
--     src/services/artist.service.js, updateProfile
-- WRITE
UPDATE artist_profiles
SET hourly_rate = 3800.00,
    is_available = true
WHERE id = '22222222-2222-2222-2222-222222222201'
RETURNING id, stage_name, hourly_rate;

-- 2.6 Band members: List all active members of a band with their roles
--     src/services/band.service.js, getBandDetails
-- READ
SELECT b.name AS band_name,
       bm.role AS member_role,
       ap.stage_name,
       i.name AS instrument_name
FROM bands b
JOIN band_members bm ON bm.band_id = b.id
JOIN artist_profiles ap ON ap.id = bm.artist_id
LEFT JOIN instruments i ON i.id = bm.instrument_id
WHERE b.id = '33333333-3333-3333-3333-333333333301'
  AND bm.is_active = true;

-- 2.7 Add member to band: Insert a new band member record
--     src/services/band.service.js, addMember
-- WRITE
INSERT INTO band_members (id, band_id, artist_id, role, instrument_id, joined_date)
VALUES (gen_random_uuid(), '33333333-3333-3333-3333-333333333301', '22222222-2222-2222-2222-222222222204', 'Guest Bassist', 3, CURRENT_DATE)
RETURNING id, band_id, artist_id, role;

-- 2.8 Venue search: Find venues in a city with minimum capacity and their operating hours
--     src/services/venue.service.js, searchVenues
-- READ
SELECT v.name, v.city, v.capacity, v.hourly_rate,
       va.open_time, va.close_time
FROM venues v
JOIN venue_availabilities va ON va.venue_id = v.id
WHERE v.city = 'Mumbai'
  AND v.capacity >= 500
  AND va.day_of_week = 5;

-- 2.9 Organizer events: List events created by an organizer
--     src/services/event.service.js, getEventsByOrganizer
-- READ
SELECT e.id, e.title, e.event_type, e.status, e.start_time, e.budget,
       v.name AS venue_name
FROM events e
LEFT JOIN venues v ON v.id = e.venue_id
WHERE e.organizer_id = '11111111-1111-1111-1111-111111111102';

-- 2.10 Event requirements: View skill requirements for an event
--      src/services/event.service.js, getEventRequirements
-- READ
SELECT er.id, er.min_experience_years, er.professional_type, er.quantity,
       s.name AS skill_name
FROM event_requirements er
LEFT JOIN skills s ON s.id = er.skill_id
WHERE er.event_id = '88888888-8888-8888-8888-888888888801';

-- 2.11 Create booking: Insert a new booking request
--      src/services/booking.service.js, createBooking
-- WRITE
INSERT INTO bookings (id, event_id, artist_id, band_id, venue_id, start_time, end_time, status, fee, created_by)
VALUES (
    gen_random_uuid(),
    '88888888-8888-8888-8888-888888888802',
    '22222222-2222-2222-2222-222222222201',
    NULL,
    NULL,
    '2026-11-21 21:00:00+05:30',
    '2026-11-21 22:00:00+05:30',
    'PENDING',
    10000.00,
    '11111111-1111-1111-1111-111111111102'
)
RETURNING id, event_id, status, fee;

-- 2.12 Update booking status: Confirm a pending booking
--      src/services/booking.service.js, updateBookingStatus
-- WRITE
UPDATE bookings
SET status = 'CONFIRMED'
WHERE id = '99999999-9999-9999-9999-999999999903'
RETURNING id, status, fee;

-- 2.13 Cancel booking: Change status to cancelled
--      src/services/booking.service.js, cancelBooking
-- WRITE
UPDATE bookings
SET status = 'CANCELLED'
WHERE id = '99999999-9999-9999-9999-999999999903'
RETURNING id, status;

-- 2.14 Equipment reservations: View equipment reserved for an event
--      src/services/equipment.service.js, getEventEquipment
-- READ
SELECT eq.name AS equipment_name, eq.category, er.quantity, er.status
FROM equipment_reservations er
JOIN equipment eq ON eq.id = er.equipment_id
WHERE er.event_id = '88888888-8888-8888-8888-888888888801';

-- 2.15 Setlist tracks: Get songs in a setlist in playback order
--      src/services/setlist.service.js, getSetlist
-- READ
SELECT ss.position, s.title, s.duration_seconds
FROM setlist_songs ss
JOIN songs s ON s.id = ss.song_id
WHERE ss.setlist_id = 'cccccccc-cccc-cccc-cccc-ccccccccccc1'
ORDER BY ss.position ASC;

-- 2.16 Add track to setlist: Insert song with sequential position
--      src/services/setlist.service.js, addSongToSetlist
-- WRITE
INSERT INTO setlist_songs (id, setlist_id, song_id, position)
VALUES (gen_random_uuid(), 'cccccccc-cccc-cccc-cccc-ccccccccccc1', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3', 3)
RETURNING id, setlist_id, song_id, position;

-- 2.17 Rehearsal details: Get rehearsal info, band, and participants
--      src/services/rehearsal.service.js, getRehearsalDetails
-- READ
SELECT r.start_time, r.end_time, b.name AS band_name, v.name AS venue_name,
       ap.stage_name, rp.confirmed
FROM rehearsals r
JOIN bands b ON b.id = r.band_id
LEFT JOIN venues v ON v.id = r.venue_id
JOIN rehearsal_participants rp ON rp.rehearsal_id = r.id
JOIN artist_profiles ap ON ap.id = rp.artist_id
WHERE r.id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1';

-- 2.18 Confirm rehearsal attendance: Mark participant as confirmed
--      src/services/rehearsal.service.js, confirmAttendance
-- WRITE
UPDATE rehearsal_participants
SET confirmed = true
WHERE rehearsal_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1'
  AND artist_id = '22222222-2222-2222-2222-222222222201'
RETURNING rehearsal_id, artist_id, confirmed;


-- ----------------------------------------------------------------------------
-- Part 3: Core algorithms and business queries
-- ----------------------------------------------------------------------------

-- 3.1 Algorithm A: Artist-event matching
--     Finds available artists matching event city, genre, and minimum experience
-- READ
SELECT ap.id,
       ap.stage_name,
       ap.professional_type,
       ap.experience_years,
       ap.hourly_rate,
       g.name AS matched_genre,
       s.name AS matched_skill,
       ask.proficiency
FROM artist_profiles ap
JOIN artist_genres ag ON ag.artist_id = ap.id
JOIN genres g ON g.id = ag.genre_id
JOIN artist_skills ask ON ask.artist_id = ap.id
JOIN skills s ON s.id = ask.skill_id
WHERE ap.is_available = true
  AND ap.city = 'Mumbai'
  AND g.name = 'Rock'
  AND ap.experience_years >= 5
ORDER BY ap.experience_years DESC;

-- 3.2 Algorithm B: Booking conflict detection
--     Checks if an artist has an overlapping booking during the requested time slot
-- READ
SELECT id, artist_id, start_time, end_time, status
FROM bookings
WHERE artist_id = '22222222-2222-2222-2222-222222222205'
  AND status IN ('PENDING', 'CONFIRMED')
  AND start_time < '2026-11-20 23:00:00+05:30'
  AND end_time > '2026-11-20 18:00:00+05:30';

-- 3.3 Algorithm C: Setlist duration calculation
--     Compares total song duration against the setlist target duration
-- READ
SELECT sl.id,
       sl.name,
       sl.target_duration_seconds,
       SUM(s.duration_seconds) AS current_duration_seconds,
       sl.target_duration_seconds - SUM(s.duration_seconds) AS remaining_seconds
FROM setlists sl
JOIN setlist_songs ss ON ss.setlist_id = sl.id
JOIN songs s ON s.id = ss.song_id
WHERE sl.id = 'cccccccc-cccc-cccc-cccc-ccccccccccc1'
GROUP BY sl.id, sl.name, sl.target_duration_seconds;

-- 3.4 Equipment availability check
--     Calculates available quantity by subtracting reserved units from total inventory
-- READ
SELECT eq.id,
       eq.name,
       eq.total_quantity,
       COALESCE(SUM(er.quantity), 0) AS reserved_units,
       eq.total_quantity - COALESCE(SUM(er.quantity), 0) AS available_units
FROM equipment eq
LEFT JOIN equipment_reservations er
       ON er.equipment_id = eq.id
      AND er.status = 'RESERVED'
GROUP BY eq.id, eq.name, eq.total_quantity;


-- ----------------------------------------------------------------------------
-- Part 4: Reports, analytics, and integrity checks
-- ----------------------------------------------------------------------------

-- 4.1 View: Event summary with venue and organizer details
-- WRITE
CREATE OR REPLACE VIEW v_event_summary AS
SELECT e.id AS event_id,
       e.title,
       e.event_type,
       e.status,
       e.start_time,
       e.budget,
       v.name AS venue_name,
       v.city AS venue_city,
       u.first_name || ' ' || u.last_name AS organizer_name
FROM events e
JOIN users u ON u.id = e.organizer_id
LEFT JOIN venues v ON v.id = e.venue_id;

-- READ
SELECT * FROM v_event_summary;

-- 4.2 Aggregation with HAVING: Artists with confirmed booking revenue
-- READ
SELECT ap.stage_name,
       COUNT(b.id) AS total_bookings,
       SUM(b.fee) AS total_earnings
FROM artist_profiles ap
JOIN bookings b ON b.artist_id = ap.id
WHERE b.status = 'CONFIRMED'
GROUP BY ap.stage_name
HAVING COUNT(b.id) > 0;

-- 4.3 Window function (RANK): Rank artists by experience in each professional type
-- READ
SELECT stage_name,
       professional_type,
       experience_years,
       RANK() OVER (PARTITION BY professional_type ORDER BY experience_years DESC) AS experience_rank
FROM artist_profiles;

-- 4.4 Window function (running total): Cumulative event budget per organizer
-- READ
SELECT organizer_id,
       title,
       start_time,
       budget,
       SUM(budget) OVER (PARTITION BY organizer_id ORDER BY start_time) AS cumulative_budget
FROM events;

-- 4.5 Subquery: Find bookings where fee is higher than the average fee
-- READ
SELECT id, event_id, fee
FROM bookings
WHERE fee > (SELECT AVG(fee) FROM bookings WHERE fee IS NOT NULL);

-- 4.6 Set operation (INTERSECT): Artists who perform solo AND are in a band
-- READ
SELECT artist_id FROM band_members
INTERSECT
SELECT artist_id FROM bookings WHERE artist_id IS NOT NULL;

-- 4.7 Set operation (EXCEPT): Artists who have never received a booking
-- READ
SELECT id AS artist_id FROM artist_profiles
EXCEPT
SELECT artist_id FROM bookings WHERE artist_id IS NOT NULL;

-- 4.8 Array unnest: Count how many venues offer each facility
-- READ
SELECT facility, COUNT(*) AS total_venues
FROM venues, UNNEST(facilities) AS facility
GROUP BY facility;

-- 4.9 Integrity check: Verify no booking has both artist_id and band_id set
-- READ
SELECT id, artist_id, band_id
FROM bookings
WHERE artist_id IS NOT NULL AND band_id IS NOT NULL;

-- 4.10 Integrity check: Verify all end times are strictly greater than start times
-- READ
SELECT id, start_time, end_time
FROM events
WHERE end_time <= start_time;

-- 4.11 Transaction demo: Update fees inside a transaction, then rollback
-- WRITE
BEGIN;

UPDATE bookings
SET fee = fee + 2000
WHERE status = 'CONFIRMED'
RETURNING id, fee;

ROLLBACK;
