-- ==========================================
-- StageSync: Unified Music & Live Event Management Platform
-- PostgreSQL Database Schema
-- ==========================================

DROP SCHEMA IF EXISTS stagesync CASCADE;

CREATE SCHEMA stagesync;

SET search_path TO stagesync;

-- Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- ENUM TYPES

CREATE TYPE user_role AS ENUM (
    'ARTIST',
    'ORGANIZER',
    'ADMIN'
);

CREATE TYPE professional_type AS ENUM (
    'MUSICIAN',
    'SINGER',
    'DJ',
    'HOST',
    'SOUND_ENGINEER',
    'LIGHTING_TECH',
    'PHOTOGRAPHER',
    'OTHER'
);

CREATE TYPE skill_proficiency AS ENUM (
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED',
    'EXPERT'
);

CREATE TYPE equipment_category AS ENUM (
    'MICROPHONE',
    'AMPLIFIER',
    'MIXER',
    'DRUMS',
    'SPEAKER',
    'LIGHTING',
    'OTHER'
);

CREATE TYPE equipment_condition AS ENUM (
    'GOOD',
    'FAIR',
    'NEEDS_MAINTENANCE',
    'OUT_OF_SERVICE'
);

CREATE TYPE event_type AS ENUM (
    'CONCERT',
    'FESTIVAL',
    'WEDDING',
    'CORPORATE',
    'PRIVATE_PARTY',
    'CLUB_NIGHT',
    'OTHER'
);

CREATE TYPE event_status AS ENUM (
    'DRAFT',
    'PUBLISHED',
    'CONFIRMED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED'
);

CREATE TYPE booking_status AS ENUM (
    'PENDING',
    'CONFIRMED',
    'CANCELLED',
    'COMPLETED'
);

CREATE TYPE reservation_status AS ENUM (
    'RESERVED',
    'CHECKED_OUT',
    'RETURNED',
    'CANCELLED'
);

-- 1. USERS & AUTHENTICATION

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role user_role NOT NULL DEFAULT 'ARTIST',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. ARTIST & PROFESSIONAL PROFILES

CREATE TABLE artist_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL,
    stage_name VARCHAR(150),
    bio TEXT,
    professional_type professional_type NOT NULL,
    experience_years INTEGER NOT NULL DEFAULT 0,
    hourly_rate DECIMAL(10, 2),
    city VARCHAR(100),
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT artist_experience_non_negative_check
        CHECK (experience_years >= 0),

    CONSTRAINT fk_artist_profile_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

-- ==========================================
-- 3. REFERENCE DATA (GENRES, SKILLS, INSTRUMENTS)
-- ==========================================

CREATE TABLE genres (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE skills (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    category VARCHAR(50)
);

CREATE TABLE instruments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- ==========================================
-- 4. ARTIST QUALIFICATIONS (JUNCTION TABLES)
-- ==========================================

CREATE TABLE artist_genres (
    artist_id UUID NOT NULL,
    genre_id INTEGER NOT NULL,

    PRIMARY KEY (artist_id, genre_id),

    CONSTRAINT fk_artist_genres_artist
        FOREIGN KEY (artist_id)
        REFERENCES artist_profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_artist_genres_genre
        FOREIGN KEY (genre_id)
        REFERENCES genres(id)
        ON DELETE CASCADE
);

CREATE TABLE artist_skills (
    artist_id UUID NOT NULL,
    skill_id INTEGER NOT NULL,
    proficiency skill_proficiency NOT NULL DEFAULT 'INTERMEDIATE',

    PRIMARY KEY (artist_id, skill_id),

    CONSTRAINT fk_artist_skills_artist
        FOREIGN KEY (artist_id)
        REFERENCES artist_profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_artist_skills_skill
        FOREIGN KEY (skill_id)
        REFERENCES skills(id)
        ON DELETE CASCADE
);

-- ==========================================
-- 5. BANDS & MEMBERSHIPS
-- ==========================================

CREATE TABLE bands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    formed_date DATE,
    bio TEXT,
    genre_id INTEGER,
    created_by UUID NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bands_creator
        FOREIGN KEY (created_by)
        REFERENCES users(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bands_genre
        FOREIGN KEY (genre_id)
        REFERENCES genres(id)
        ON DELETE SET NULL
);

CREATE TABLE band_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    band_id UUID NOT NULL,
    artist_id UUID NOT NULL,
    role VARCHAR(100) NOT NULL,
    instrument_id INTEGER,
    joined_date DATE NOT NULL DEFAULT CURRENT_DATE,
    left_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT band_members_dates_check
        CHECK (left_date IS NULL OR left_date >= joined_date),

    CONSTRAINT fk_band_members_band
        FOREIGN KEY (band_id)
        REFERENCES bands(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_band_members_artist
        FOREIGN KEY (artist_id)
        REFERENCES artist_profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_band_members_instrument
        FOREIGN KEY (instrument_id)
        REFERENCES instruments(id)
        ON DELETE SET NULL
);

-- ==========================================
-- 6. VENUES & AVAILABILITIES
-- ==========================================

CREATE TABLE venues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    address VARCHAR(300) NOT NULL,
    city VARCHAR(100) NOT NULL,
    capacity INTEGER NOT NULL,
    hourly_rate DECIMAL(10, 2),
    description TEXT,
    facilities TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_active BOOLEAN NOT NULL DEFAULT true,
    owner_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT venues_capacity_positive_check
        CHECK (capacity > 0),

    CONSTRAINT fk_venues_owner
        FOREIGN KEY (owner_id)
        REFERENCES users(id)
        ON DELETE RESTRICT
);

CREATE TABLE venue_availabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id UUID NOT NULL,
    day_of_week INTEGER NOT NULL,
    open_time VARCHAR(8) NOT NULL,
    close_time VARCHAR(8) NOT NULL,

    CONSTRAINT venue_availabilities_day_and_time_check
        CHECK (day_of_week >= 0 AND day_of_week <= 6 AND close_time > open_time),

    CONSTRAINT uq_venue_availability_day
        UNIQUE (venue_id, day_of_week),

    CONSTRAINT fk_venue_availabilities_venue
        FOREIGN KEY (venue_id)
        REFERENCES venues(id)
        ON DELETE CASCADE
);

-- ==========================================
-- 7. EQUIPMENT & INVENTORY
-- ==========================================

CREATE TABLE equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    category equipment_category NOT NULL,
    total_quantity INTEGER NOT NULL DEFAULT 1,
    condition equipment_condition NOT NULL DEFAULT 'GOOD',
    owner_id UUID NOT NULL,
    description TEXT,
    daily_rate DECIMAL(10, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT equipment_quantity_positive_check
        CHECK (total_quantity > 0),

    CONSTRAINT fk_equipment_owner
        FOREIGN KEY (owner_id)
        REFERENCES users(id)
        ON DELETE RESTRICT
);

-- ==========================================
-- 8. EVENTS & REQUIREMENTS
-- ==========================================

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    event_type event_type NOT NULL,
    genre_id INTEGER,
    venue_id UUID,
    organizer_id UUID NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    performance_duration_minutes INTEGER,
    max_performers INTEGER,
    status event_status NOT NULL DEFAULT 'DRAFT',
    budget DECIMAL(12, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT events_time_order_check
        CHECK (end_time > start_time),

    CONSTRAINT fk_events_organizer
        FOREIGN KEY (organizer_id)
        REFERENCES users(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_events_genre
        FOREIGN KEY (genre_id)
        REFERENCES genres(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_events_venue
        FOREIGN KEY (venue_id)
        REFERENCES venues(id)
        ON DELETE SET NULL
);

CREATE TABLE equipment_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_id UUID NOT NULL,
    event_id UUID NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status reservation_status NOT NULL DEFAULT 'RESERVED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT reservations_time_order_check
        CHECK (end_time > start_time),

    CONSTRAINT reservations_quantity_positive_check
        CHECK (quantity > 0),

    CONSTRAINT fk_reservations_equipment
        FOREIGN KEY (equipment_id)
        REFERENCES equipment(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_reservations_event
        FOREIGN KEY (event_id)
        REFERENCES events(id)
        ON DELETE CASCADE
);

CREATE TABLE event_requirements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL,
    skill_id INTEGER,
    genre_id INTEGER,
    min_experience_years INTEGER NOT NULL DEFAULT 0,
    professional_type professional_type,
    is_mandatory BOOLEAN NOT NULL DEFAULT true,
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT event_requirements_values_check
        CHECK (quantity > 0 AND min_experience_years >= 0),

    CONSTRAINT fk_event_requirements_event
        FOREIGN KEY (event_id)
        REFERENCES events(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_event_requirements_skill
        FOREIGN KEY (skill_id)
        REFERENCES skills(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_event_requirements_genre
        FOREIGN KEY (genre_id)
        REFERENCES genres(id)
        ON DELETE SET NULL
);

-- ==========================================
-- 9. BOOKINGS & SCHEDULES (WITH CONCURRENCY EXCLUSIONS)
-- ==========================================

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL,
    artist_id UUID,
    band_id UUID,
    venue_id UUID,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status booking_status NOT NULL DEFAULT 'PENDING',
    fee DECIMAL(10, 2),
    notes TEXT,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT bookings_time_order_check
        CHECK (end_time > start_time),

    CONSTRAINT booking_performer_target_check
        CHECK (
            (artist_id IS NOT NULL AND band_id IS NULL) OR
            (artist_id IS NULL AND band_id IS NOT NULL) OR
            (artist_id IS NULL AND band_id IS NULL AND venue_id IS NOT NULL)
        ),

    CONSTRAINT fk_bookings_event
        FOREIGN KEY (event_id)
        REFERENCES events(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_bookings_artist
        FOREIGN KEY (artist_id)
        REFERENCES artist_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bookings_band
        FOREIGN KEY (band_id)
        REFERENCES bands(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bookings_venue
        FOREIGN KEY (venue_id)
        REFERENCES venues(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bookings_creator
        FOREIGN KEY (created_by)
        REFERENCES users(id)
        ON DELETE RESTRICT,

    -- PostgreSQL Exclusion Constraints for double-booking concurrency safety
    CONSTRAINT no_artist_booking_overlap
        EXCLUDE USING gist (
            artist_id WITH =,
            tstzrange(start_time, end_time) WITH &&
        )
        WHERE (status IN ('PENDING', 'CONFIRMED') AND artist_id IS NOT NULL),

    CONSTRAINT no_band_booking_overlap
        EXCLUDE USING gist (
            band_id WITH =,
            tstzrange(start_time, end_time) WITH &&
        )
        WHERE (status IN ('PENDING', 'CONFIRMED') AND band_id IS NOT NULL),

    CONSTRAINT no_venue_booking_overlap
        EXCLUDE USING gist (
            venue_id WITH =,
            tstzrange(start_time, end_time) WITH &&
        )
        WHERE (status IN ('PENDING', 'CONFIRMED') AND venue_id IS NOT NULL)
);

-- ==========================================
-- 10. SONGS, REPERTOIRE & SETLISTS
-- ==========================================

CREATE TABLE songs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    artist_name VARCHAR(200),
    duration_seconds INTEGER NOT NULL,
    genre_id INTEGER,
    tempo_bpm INTEGER,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT songs_duration_positive_check
        CHECK (duration_seconds > 0),

    CONSTRAINT fk_songs_creator
        FOREIGN KEY (created_by)
        REFERENCES users(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_songs_genre
        FOREIGN KEY (genre_id)
        REFERENCES genres(id)
        ON DELETE SET NULL
);

CREATE TABLE band_songs (
    band_id UUID NOT NULL,
    song_id UUID NOT NULL,

    PRIMARY KEY (band_id, song_id),

    CONSTRAINT fk_band_songs_band
        FOREIGN KEY (band_id)
        REFERENCES bands(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_band_songs_song
        FOREIGN KEY (song_id)
        REFERENCES songs(id)
        ON DELETE CASCADE
);

CREATE TABLE setlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    event_id UUID,
    booking_id UUID,
    target_duration_seconds INTEGER NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT setlists_target_duration_positive_check
        CHECK (target_duration_seconds > 0),

    CONSTRAINT fk_setlists_event
        FOREIGN KEY (event_id)
        REFERENCES events(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_setlists_booking
        FOREIGN KEY (booking_id)
        REFERENCES bookings(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_setlists_creator
        FOREIGN KEY (created_by)
        REFERENCES users(id)
        ON DELETE RESTRICT
);

CREATE TABLE setlist_songs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setlist_id UUID NOT NULL,
    song_id UUID NOT NULL,
    position INTEGER NOT NULL,

    CONSTRAINT uq_setlist_song_position
        UNIQUE (setlist_id, position),

    CONSTRAINT uq_setlist_song_item
        UNIQUE (setlist_id, song_id),

    CONSTRAINT fk_setlist_songs_setlist
        FOREIGN KEY (setlist_id)
        REFERENCES setlists(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_setlist_songs_song
        FOREIGN KEY (song_id)
        REFERENCES songs(id)
        ON DELETE CASCADE
);

-- ==========================================
-- 11. REHEARSALS
-- ==========================================

CREATE TABLE rehearsals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    band_id UUID,
    event_id UUID,
    venue_id UUID,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    notes TEXT,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT rehearsals_time_order_check
        CHECK (end_time > start_time),

    CONSTRAINT fk_rehearsals_band
        FOREIGN KEY (band_id)
        REFERENCES bands(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_rehearsals_event
        FOREIGN KEY (event_id)
        REFERENCES events(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_rehearsals_venue
        FOREIGN KEY (venue_id)
        REFERENCES venues(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_rehearsals_creator
        FOREIGN KEY (created_by)
        REFERENCES users(id)
        ON DELETE RESTRICT
);

CREATE TABLE rehearsal_participants (
    rehearsal_id UUID NOT NULL,
    artist_id UUID NOT NULL,
    confirmed BOOLEAN NOT NULL DEFAULT false,

    PRIMARY KEY (rehearsal_id, artist_id),

    CONSTRAINT fk_rehearsal_participants_rehearsal
        FOREIGN KEY (rehearsal_id)
        REFERENCES rehearsals(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_rehearsal_participants_artist
        FOREIGN KEY (artist_id)
        REFERENCES artist_profiles(id)
        ON DELETE CASCADE
);

CREATE TABLE rehearsal_songs (
    rehearsal_id UUID NOT NULL,
    song_id UUID NOT NULL,

    PRIMARY KEY (rehearsal_id, song_id),

    CONSTRAINT fk_rehearsal_songs_rehearsal
        FOREIGN KEY (rehearsal_id)
        REFERENCES rehearsals(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_rehearsal_songs_song
        FOREIGN KEY (song_id)
        REFERENCES songs(id)
        ON DELETE CASCADE
);

-- ==========================================
-- INDEXES FOR QUERY OPTIMIZATION
-- ==========================================

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

CREATE INDEX idx_artist_profiles_city ON artist_profiles(city);
CREATE INDEX idx_artist_profiles_prof_available ON artist_profiles(professional_type, is_available);

CREATE INDEX idx_bands_created_by ON bands(created_by);
CREATE INDEX idx_bands_genre_id ON bands(genre_id);

CREATE INDEX idx_band_members_band_active ON band_members(band_id, is_active);
CREATE INDEX idx_band_members_artist_active ON band_members(artist_id, is_active);

CREATE INDEX idx_venues_city_active ON venues(city, is_active);
CREATE INDEX idx_venues_capacity ON venues(capacity);

CREATE INDEX idx_equipment_category_condition ON equipment(category, condition);
CREATE INDEX idx_equipment_owner_id ON equipment(owner_id);

CREATE INDEX idx_equipment_reservations_lookup ON equipment_reservations(equipment_id, status, start_time, end_time);
CREATE INDEX idx_equipment_reservations_event ON equipment_reservations(event_id);

CREATE INDEX idx_events_organizer_status ON events(organizer_id, status);
CREATE INDEX idx_events_time_window ON events(start_time, end_time);
CREATE INDEX idx_events_venue ON events(venue_id);
CREATE INDEX idx_events_genre ON events(genre_id);

CREATE INDEX idx_event_requirements_event ON event_requirements(event_id);

CREATE INDEX idx_bookings_artist_window ON bookings(artist_id, status, start_time, end_time);
CREATE INDEX idx_bookings_band_window ON bookings(band_id, status, start_time, end_time);
CREATE INDEX idx_bookings_venue_window ON bookings(venue_id, status, start_time, end_time);
CREATE INDEX idx_bookings_event ON bookings(event_id);

CREATE INDEX idx_songs_genre ON songs(genre_id);
CREATE INDEX idx_songs_duration ON songs(duration_seconds);

CREATE INDEX idx_setlists_event ON setlists(event_id);
CREATE INDEX idx_setlists_booking ON setlists(booking_id);

CREATE INDEX idx_rehearsals_band_window ON rehearsals(band_id, start_time, end_time);
CREATE INDEX idx_rehearsals_venue_window ON rehearsals(venue_id, start_time, end_time);
CREATE INDEX idx_rehearsals_event ON rehearsals(event_id);
