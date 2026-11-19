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


