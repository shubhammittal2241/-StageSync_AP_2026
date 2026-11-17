# Database Normalization: StageSync

This document traces the normalization of the StageSync database from an unnormalized representation (UNF) through First Normal Form (1NF), Second Normal Form (2NF), Third Normal Form (3NF), and Boyce-Codd Normal Form (BCNF).

---

## 1. Domain overview

StageSync is an end-to-end platform for live music event management, artist discovery, venue scheduling, equipment reservation, and event production workflows. It coordinates multiple stakeholders: event organizers, solo artists, bands, venue managers, and production crew.

The primary domain entities include:
- **Users**: Registered accounts with email, hashed passwords, roles (`ADMIN`, `ORGANIZER`, `ARTIST`), and account status.
- **Artist Profiles**: Detailed performer profiles linked 1:1 to users, containing stage name, bio, professional type (musician, singer, DJ, sound engineer), years of experience, hourly rates, location, and availability status.
- **Reference Taxonomies**: Dictionaries for musical genres, professional skills, and instruments.
- **Artist Qualifications**: Association tables linking artists to multiple genres (`artist_genres`) and skills with proficiency ratings (`artist_skills`).
- **Bands and Memberships**: Musical groups composed of multiple artists, tracking member roles, instruments, and join/leave dates.
- **Venues and Operating Hours**: Physical performance locations with address, capacity, facility tags, and weekly operating schedules (`venue_availabilities`).
- **Equipment and Reservations**: Hardware inventory (audio, lighting, instruments) categorized by condition and quantity, linked to events through time-bounded leases (`equipment_reservations`).
- **Events and Requirements**: Scheduled live events with dates, duration, budget, and talent requirements (`event_requirements`).
- **Bookings**: Contractual allocations connecting an event to an artist, band, or venue with concurrency protection against double-booking.
- **Repertoire, Setlists, and Rehearsals**: Track library (`songs`), band repertoires (`band_songs`), duration-constrained setlists (`setlists`, `setlist_songs`), and practice sessions (`rehearsals`, `rehearsal_participants`, `rehearsal_songs`).

---

## 2. Unnormalized form (UNF)

In an unnormalized design, all application data lives in a single monolithic structure or nested document. Attributes contain repeating groups, multi-valued arrays, and mixed concerns across users, artists, bands, venues, events, bookings, and repertoires.

### Monolithic unnormalized schema

```text
UNF_STAGESYNC(
    user_id,
    user_email,
    password_hash,
    user_name,
    user_role,
    artist_profile {
        stage_name,
        bio,
        professional_type,
        experience_years,
        hourly_rate,
        city,
        skills [ { skill_id, skill_name, proficiency } ],
        genres [ { genre_id, genre_name } ]
    },
    bands [ {
        band_id,
        band_name,
        band_genre,
        members [ { member_artist_id, member_role, instrument_name, joined_date } ],
        repertoire_songs [ { song_id, song_title, duration_seconds } ]
    } ],
    venues [ {
        venue_id,
        venue_name,
        address,
        city,
        capacity,
        hourly_rate,
        operating_hours [ { day_of_week, open_time, close_time } ]
    } ],
    events [ {
        event_id,
        event_title,
        event_type,
        start_time,
        end_time,
        budget,
        venue_id,
        venue_name,
        requirements [ { skill_name, min_exp, quantity } ],
        bookings [ {
            booking_id,
            performer_type,
            performer_name,
            booking_start,
            booking_end,
            fee,
            status,
            setlist {
                setlist_name,
                target_duration,
                songs [ { song_id, title, duration_seconds, sequence_pos } ]
            }
        } ],
        equipment_reservations [ {
            equipment_id,
            equipment_name,
            category,
            quantity,
            start_time,
            end_time
        } ]
    } ]
)
```

### Sample unnormalized record

| user_id | user_email | user_role | artist_profile | bands | events |
| :--- | :--- | :--- | :--- | :--- | :--- |
| usr_101 | maya@stagesync.io | ARTIST | `{stage_name: "Maya Lin", type: "SINGER", exp: 6, skills: [{name: "Vocal", lvl: "EXPERT"}], genres: [{name: "Jazz"}]}` | `[{band_id: "b_01", name: "The Blue Notes", members: [{artist: "usr_101", role: "Lead Vocal", inst: "Vocals"}]}]` | `[{event_id: "evt_99", title: "Autumn Jazz Fest", venue: "Grand Theatre", bookings: [{booking_id: "bk_01", fee: 1200.00, status: "CONFIRMED"}]}]` |

### Problems in UNF
1. **Repeating groups and nested hierarchies**: Attributes such as `skills`, `genres`, `bands`, `members`, `events`, `bookings`, and `setlists` store lists of values, which violates relational atomicity.
2. **Variable row sizes**: A user organizing multiple events or playing in multiple bands requires unbounded and deeply nested structures.
3. **Severe data redundancy**: Venue addresses, capacities, genre labels, and song durations are duplicated across every event and setlist in which they appear.
4. **Mixed concerns**: Artist profiles, event logistics, and equipment inventory cannot be queried or updated independently.

---

## 3. First normal form (1NF)

### 1NF rules
A relation is in First Normal Form (1NF) if:
1. Every attribute value is atomic (a single indivisible value per cell; no arrays, lists, or nested objects).
2. All entries in a column are of the same domain/data type.
3. Each column has a unique name.
4. The physical order of rows and columns does not matter.
5. A unique primary key exists to identify each row.

### Transformation from UNF to 1NF

To convert the UNF structure into 1NF, all repeating groups and nested arrays are flattened into individual rows so that every field holds an atomic value.

For the event booking and performance schedule pipeline, the flattened relation is:

```text
FLAT_EVENT_BOOKING_ROSTER(
    user_id,
    user_email,
    user_first_name,
    user_last_name,
    user_role,
    artist_id,
    stage_name,
    professional_type,
    skill_id,
    skill_name,
    skill_proficiency,
    genre_id,
    genre_name,
    band_id,
    band_name,
    instrument_id,
    instrument_name,
    venue_id,
    venue_name,
    venue_city,
    venue_capacity,
    event_id,
    event_title,
    event_start_time,
    event_end_time,
    booking_id,
    booking_start_time,
    booking_end_time,
    booking_fee,
    booking_status,
    song_id,
    song_title,
    song_duration_seconds,
    setlist_id,
    setlist_name,
    setlist_position
)
```

### Sample 1NF tabular data

| event_id | artist_id | band_id | skill_id | venue_id | song_id | setlist_pos | booking_id | stage_name | venue_name | song_title |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| evt_01 | art_11 | b_01 | sk_05 | ven_88 | s_101 | 1 | bk_501 | Maya Lin | Grand Hall | Autumn Leaves |
| evt_01 | art_11 | b_01 | sk_05 | ven_88 | s_102 | 2 | bk_501 | Maya Lin | Grand Hall | Blue in Green |
| evt_01 | art_11 | b_01 | sk_08 | ven_88 | s_101 | 1 | bk_501 | Maya Lin | Grand Hall | Autumn Leaves |
| evt_01 | art_11 | b_01 | sk_08 | ven_88 | s_102 | 2 | bk_501 | Maya Lin | Grand Hall | Blue in Green |
| evt_02 | art_22 | b_02 | sk_01 | ven_99 | s_205 | 1 | bk_502 | John Trio | Jazz Club | Cantaloupe Island |

### Composite primary key in 1NF
To uniquely identify each record in `FLAT_EVENT_BOOKING_ROSTER`, the composite primary key must combine the intersecting entity keys:

PK = { event_id, booking_id, artist_id, band_id, skill_id, song_id, setlist_position }

### Functional dependencies in 1NF
- {user_id} -> user_email, user_first_name, user_last_name, user_role
- {artist_id} -> user_id, stage_name, professional_type
- {skill_id} -> skill_name
- {genre_id} -> genre_name
- {instrument_id} -> instrument_name
- {venue_id} -> venue_name, venue_city, venue_capacity
- {event_id} -> event_title, event_start_time, event_end_time, venue_id
- {booking_id} -> event_id, booking_start_time, booking_end_time, booking_fee, booking_status
- {song_id} -> song_title, song_duration_seconds
- {setlist_id, setlist_position} -> song_id
- {artist_id, skill_id} -> skill_proficiency

### Anomalies present in 1NF
1. **Insertion anomaly**:
   - A new venue cannot be registered until an event, booking, artist, and setlist exist for that venue.
   - A newly written song cannot be added to the catalogue without attaching it to an existing event booking.
   - A user cannot sign up without being immediately tied to a live booking row.
2. **Update anomaly**:
   - If the duration of song `s_101` changes, every row where `s_101` appears across all events and setlists must be updated. Missing even one row results in inconsistent data.
   - Modifying `venue_capacity` for `Grand Hall` requires updating every row referencing that venue.
3. **Deletion anomaly**:
   - If an event (`evt_02`) is cancelled and its rows are deleted, the venue details for `Jazz Club` and the record for song `s_205` are permanently lost if no other events reference them.

---

## 4. Second normal form (2NF)

### 2NF rules
A relation is in Second Normal Form (2NF) if:
1. It is in 1NF.
2. No non-prime attribute is partially dependent on any candidate key. Every non-key attribute must depend on the entire candidate key, not a proper subset of it.

Note: Any table with a single-attribute primary key is automatically in 2NF once it satisfies 1NF, since no partial subset of a single attribute can exist.

### Identification of partial dependencies

In `FLAT_EVENT_BOOKING_ROSTER`, the composite primary key is:
PK = { event_id, booking_id, artist_id, band_id, skill_id, song_id, setlist_position }

Several attributes depend on only a subset of this composite key:
- Partial dependency 1: {artist_id} -> user_id, stage_name, professional_type (independent of event, booking, or song).
- Partial dependency 2: {artist_id, skill_id} -> skill_proficiency (independent of event or booking).
- Partial dependency 3: {song_id} -> song_title, song_duration_seconds (independent of event, artist, or setlist).
- Partial dependency 4: {venue_id} -> venue_name, venue_city, venue_capacity.
- Partial dependency 5: {event_id} -> event_title, event_start_time, event_end_time, venue_id.
- Partial dependency 6: {booking_id} -> event_id, booking_start_time, booking_end_time, booking_fee, booking_status.

### Decomposition into 2NF relations

To resolve partial dependencies, we decompose `FLAT_EVENT_BOOKING_ROSTER` into separate relations based on each functional determinant.

#### 1. users_2nf
- Attributes: `user_id`, `email`, `password_hash`, `first_name`, `last_name`, `role`
- Primary key: `user_id`

#### 2. artist_profiles_2nf
- Attributes: `artist_id`, `user_id`, `stage_name`, `bio`, `professional_type`, `experience_years`, `hourly_rate`, `city`
- Primary key: `artist_id`

#### 3. skills_2nf
- Attributes: `skill_id`, `name`, `category`
- Primary key: `skill_id`

#### 4. artist_skills_2nf
- Attributes: `artist_id`, `skill_id`, `proficiency`
- Primary key: `{artist_id, skill_id}`

#### 5. venues_2nf
- Attributes: `venue_id`, `name`, `address`, `city`, `capacity`, `hourly_rate`, `owner_id`
- Primary key: `venue_id`

#### 6. events_2nf
- Attributes: `event_id`, `title`, `event_type`, `organizer_id`, `venue_id`, `venue_name`, `venue_city`, `start_time`, `end_time`, `budget`
- Primary key: `event_id`

#### 7. bookings_2nf
- Attributes: `booking_id`, `event_id`, `artist_id`, `band_id`, `venue_id`, `start_time`, `end_time`, `status`, `fee`
- Primary key: `booking_id`

#### 8. songs_2nf
- Attributes: `song_id`, `title`, `duration_seconds`, `genre_id`, `created_by`
- Primary key: `song_id`

#### 9. setlist_songs_2nf
- Attributes: `setlist_id`, `position`, `song_id`
- Primary key: `{setlist_id, position}`

### Remaining anomalies in 2NF (transitive dependencies)
While partial key dependencies are removed, relations in 2NF still contain transitive functional dependencies:
- In `events_2nf`:
  `event_id -> venue_id` and `venue_id -> venue_name, venue_city`.
  Therefore, `event_id -> venue_name` is a transitive dependency through `venue_id`. If a venue's name is updated, every event hosted at that venue must be modified.
- In `artist_profiles_2nf`:
  `artist_id -> user_id` and `user_id -> email, role`.
  User details depend transitively on `artist_id`. Storing user credentials inside the artist profile creates duplication and prevents non-artist users (such as organizers and administrators) from having clean accounts.

---

## 5. Third normal form (3NF)

### 3NF rules
A relation is in Third Normal Form (3NF) if:
1. It is in 2NF.
2. No non-prime attribute is transitively dependent on any candidate key.
3. Formally: For every non-trivial functional dependency X -> Y, either:
   - X is a superkey, or
   - Y is a prime attribute (member of a candidate key).

### Identification of transitive dependencies

1. **Event to venue details**:
   In `events_2nf`, candidate key is `{event_id}`.
   Dependencies: `{event_id} -> venue_id` and `{venue_id} -> {venue_name, venue_city, venue_capacity}`.
   `venue_id` is not a superkey in `events_2nf`, so venue details must be moved out.
2. **Band member to instrument**:
   If `band_members` contains `instrument_name`, we have:
   `{band_id, artist_id} -> instrument_id` and `{instrument_id} -> instrument_name`.
   Storing instrument names directly in the membership relation violates 3NF.
3. **Setlist to song track metadata**:
   In `setlist_songs`, storing title and duration alongside `{setlist_id, position}` creates:
   `{setlist_id, position} -> song_id -> {song_title, duration_seconds}`.
   `song_id` must reference the independent `songs` relation.

### Decomposition into 3NF relations

To satisfy 3NF, every non-key determinant is extracted into its own table, keeping only foreign keys in dependent relations.

#### 1. Core authentication and profiles
```text
users(
    id,              -- Primary Key
    email,           -- Unique
    password_hash,
    first_name,
    last_name,
    role,
    is_active,
    created_at,
    updated_at
)

artist_profiles(
    id,                -- Primary Key
    user_id,           -- Foreign Key -> users(id), Unique
    stage_name,
    bio,
    professional_type,
    experience_years,
    hourly_rate,
    city,
    is_available,
    created_at,
    updated_at
)
```

#### 2. Dictionaries and taxonomies
```text
genres(
    id,   -- Primary Key
    name  -- Unique
)

skills(
    id,       -- Primary Key
    name,     -- Unique
    category
)

instruments(
    id,   -- Primary Key
    name  -- Unique
)
```

#### 3. Qualifications junction tables
```text
artist_genres(
    artist_id, -- Foreign Key -> artist_profiles(id)
    genre_id,  -- Foreign Key -> genres(id)
    PRIMARY KEY (artist_id, genre_id)
)

artist_skills(
    artist_id,   -- Foreign Key -> artist_profiles(id)
    skill_id,    -- Foreign Key -> skills(id)
    proficiency,
    PRIMARY KEY (artist_id, skill_id)
)
```

#### 4. Bands and memberships
```text
bands(
    id,          -- Primary Key
    name,
    formed_date,
    bio,
    genre_id,    -- Foreign Key -> genres(id)
    created_by,  -- Foreign Key -> users(id)
    is_active,
    created_at,
    updated_at
)

band_members(
    id,            -- Primary Key
    band_id,       -- Foreign Key -> bands(id)
    artist_id,     -- Foreign Key -> artist_profiles(id)
    role,
    instrument_id, -- Foreign Key -> instruments(id)
    joined_date,
    left_date,
    is_active,
    created_at,
    updated_at
)
```

#### 5. Venues and operating schedules
```text
venues(
    id,          -- Primary Key
    name,
    address,
    city,
    capacity,
    hourly_rate,
    description,
    facilities,
    is_active,
    owner_id,    -- Foreign Key -> users(id)
    created_at,
    updated_at
)

venue_availabilities(
    id,          -- Primary Key
    venue_id,    -- Foreign Key -> venues(id)
    day_of_week,
    open_time,
    close_time,
    UNIQUE (venue_id, day_of_week)
)
```

#### 6. Events and requirements
```text
events(
    id,                           -- Primary Key
    title,
    description,
    event_type,
    genre_id,                     -- Foreign Key -> genres(id)
    venue_id,                     -- Foreign Key -> venues(id)
    organizer_id,                 -- Foreign Key -> users(id)
    start_time,
    end_time,
    performance_duration_minutes,
    max_performers,
    status,
    budget,
    created_at,
    updated_at
)

event_requirements(
    id,                   -- Primary Key
    event_id,             -- Foreign Key -> events(id)
    skill_id,             -- Foreign Key -> skills(id)
    genre_id,             -- Foreign Key -> genres(id)
    min_experience_years,
    professional_type,
    is_mandatory,
    quantity,
    created_at,
    updated_at
)
```

#### 7. Bookings and equipment reservations
```text
bookings(
    id,         -- Primary Key
    event_id,   -- Foreign Key -> events(id)
    artist_id,  -- Foreign Key -> artist_profiles(id)
    band_id,    -- Foreign Key -> bands(id)
    venue_id,   -- Foreign Key -> venues(id)
    start_time,
    end_time,
    status,
    fee,
    notes,
    created_by, -- Foreign Key -> users(id)
    created_at,
    updated_at
)

equipment(
    id,             -- Primary Key
    name,
    category,
    total_quantity,
    condition,
    owner_id,       -- Foreign Key -> users(id)
    description,
    daily_rate,
    created_at,
    updated_at
)

equipment_reservations(
    id,           -- Primary Key
    equipment_id, -- Foreign Key -> equipment(id)
    event_id,     -- Foreign Key -> events(id)
    quantity,
    start_time,
    end_time,
    status,
    created_at,
    updated_at
)
```

#### 8. Songs, setlists, and rehearsals
```text
songs(
    id,               -- Primary Key
    title,
    artist_name,
    duration_seconds,
    genre_id,         -- Foreign Key -> genres(id)
    tempo_bpm,
    created_by,       -- Foreign Key -> users(id)
    created_at,
    updated_at
)

band_songs(
    band_id, -- Foreign Key -> bands(id)
    song_id, -- Foreign Key -> songs(id)
    PRIMARY KEY (band_id, song_id)
)


setlists(
    id,                      -- Primary Key
    name,
    event_id,                -- Foreign Key -> events(id)
    booking_id,              -- Foreign Key -> bookings(id)
    target_duration_seconds,
    created_by,              -- Foreign Key -> users(id)
    created_at,
    updated_at
)


setlist_songs(
    id,         -- Primary Key
    setlist_id, -- Foreign Key -> setlists(id)
    song_id,    -- Foreign Key -> songs(id)
    position,
    UNIQUE (setlist_id, position),
    UNIQUE (setlist_id, song_id)
)


rehearsals(
    id,         -- Primary Key
    band_id,    -- Foreign Key -> bands(id)
    event_id,   -- Foreign Key -> events(id)
    venue_id,   -- Foreign Key -> venues(id)
    start_time,
    end_time,
    notes,
    created_by, -- Foreign Key -> users(id)
    created_at,
    updated_at
)

rehearsal_participants(
    rehearsal_id, -- Foreign Key -> rehearsals(id)
    artist_id,    -- Foreign Key -> artist_profiles(id)
    confirmed,
    PRIMARY KEY (rehearsal_id, artist_id)
)

rehearsal_songs(
    rehearsal_id, -- Foreign Key -> rehearsals(id)
    song_id,      -- Foreign Key -> songs(id)
    PRIMARY KEY (rehearsal_id, song_id)
)
```


---

## 6. Boyce-Codd normal form (BCNF)

### BCNF rules
Boyce-Codd Normal Form (BCNF) is a stricter version of 3NF.
A relation is in BCNF if and only if:
> For every non-trivial functional dependency X -> Y, X must be a **superkey**.

In 3NF, a dependency X -> Y is permitted if Y is a prime attribute, even when X is not a superkey. BCNF removes this condition: every determinant must be a candidate key or superkey.

### Evaluation of StageSync relations against BCNF

#### 1. `users`
- Candidate keys: `id`, `email`
- Dependencies:
  - `id -> email, password_hash, first_name, last_name, role, is_active, ...`
  - `email -> id, password_hash, first_name, last_name, role, is_active, ...`
- Determinants: Both `id` and `email` are superkeys.
- Status: **BCNF**


#### 2. `artist_profiles`
- Candidate keys: `id`, `user_id`
- Dependencies:
  - `id -> user_id, stage_name, bio, professional_type, experience_years, ...`
  - `user_id -> id, stage_name, bio, professional_type, experience_years, ...`
- Determinants: Both `id` and `user_id` are candidate keys.
- Status: **BCNF**


#### 3. `genres`, `skills`, and `instruments`
- Candidate keys: `id`, `name`
- Dependencies: `id -> name` and `name -> id`
- Determinants: Both are candidate keys.
- Status: **BCNF**


#### 4. `artist_genres` and `band_songs`
- Candidate key: `{artist_id, genre_id}` / `{band_id, song_id}`
- Dependencies: Only trivial dependencies on the composite key.
- Determinants: Full candidate key.
- Status: **BCNF**

#### 5. `artist_skills`
- Candidate key: `{artist_id, skill_id}`
- Dependencies: `{artist_id, skill_id} -> proficiency`
- Determinant: Full candidate key.
- Status: **BCNF**

#### 6. `venue_availabilities`
- Candidate keys: `id`, `{venue_id, day_of_week}`
- Dependencies:
  - `id -> venue_id, day_of_week, open_time, close_time`
  - `{venue_id, day_of_week} -> id, open_time, close_time`
- Determinants: Both are candidate keys.
- Status: **BCNF**

#### 7. `setlist_songs`
- Candidate keys:
  1. `id`
  2. `{setlist_id, position}`
  3. `{setlist_id, song_id}`
- Dependencies:
  - `id -> setlist_id, song_id, position`
  - `{setlist_id, position} -> id, song_id`
  - `{setlist_id, song_id} -> id, position`
- Determinants: All determinants are candidate keys enforced by unique constraints.
- Status: **BCNF**

#### 8. `bookings`
- Candidate key: `id`
- Dependencies: `id -> event_id, artist_id, band_id, venue_id, start_time, end_time, status, fee, ...`
- Determinant: Primary key is the sole relational determinant.
- Concurrency note: Overlap prevention across time windows is enforced via PostgreSQL exclusion constraints (`EXCLUDE USING gist`).
- Status: **BCNF**

#### 9. `rehearsal_participants` and `rehearsal_songs`
- Candidate keys: `{rehearsal_id, artist_id}` and `{rehearsal_id, song_id}`
- Dependencies: `{rehearsal_id, artist_id} -> confirmed`
- Determinants: Full candidate keys.
- Status: **BCNF**

---

## 7. Comparison summary: Normalization progression

The following table summarizes how data redundancy and anomalies are resolved across each stage:

| Normal form | Requirement | Problem addressed | StageSync schema state |
| :--- | :--- | :--- | :--- |
| **UNF** | None (nested / multi-valued) | High storage overhead, unbounded arrays, variable record sizes | Monolithic record containing nested artist profiles, bands, venues, setlists, and bookings |
| **1NF** | Atomic values, identified PK | Removes repeating groups and nested document arrays | Flat relation (`FLAT_EVENT_BOOKING_ROSTER`) with composite primary key |
| **2NF** | In 1NF + no partial dependencies | Removes attributes dependent on part of a composite key | Separated relations: `users`, `artist_profiles`, `venues`, `songs`, `skills`, `bookings` |
| **3NF** | In 2NF + no transitive dependencies | Removes non-key attributes determining other non-key attributes | Separated `genres`, `instruments`, `venue_availabilities`, `setlists`, `rehearsals` |
| **BCNF** | Every determinant is a superkey | Eliminates anomalies with alternative or overlapping candidate keys | Enforced unique constraints on `users.email`, `setlist_songs(setlist_id, position)`, `venue_availabilities(venue_id, day_of_week)` |

---

## 8. Practical engineering considerations and controlled constraints

While the database design conforms to BCNF, real-world production requirements require specific database-level mechanisms:

1. **PostgreSQL Exclusion Constraints for concurrency (`btree_gist`)**:
   - Discrete time slots create millions of empty rows and high index overhead.
   - StageSync enforces non-overlapping bookings via PostgreSQL `EXCLUDE USING gist` with `tstzrange(start_time, end_time) WITH &&`:
     - `no_artist_booking_overlap`: Prevents double-booking an artist across concurrent transactions.
     - `no_band_booking_overlap`: Prevents concurrent band overlaps.
     - `no_venue_booking_overlap`: Prevents concurrent venue scheduling conflicts.
     - Automatically restores availability when a booking is cancelled (`status = 'CANCELLED'`).
       
2. **Performer XOR validation (`CHECK` constraint)**:
   - A booking must target an artist, a band, or a standalone venue rental, but never an artist and band simultaneously.
   - StageSync enforces this with a database check constraint:
     ```sql
     CHECK (
       (artist_id IS NOT NULL AND band_id IS NULL) OR
       (artist_id IS NULL AND band_id IS NOT NULL) OR
       (artist_id IS NULL AND band_id IS NULL AND venue_id IS NOT NULL)
     )
     ```
     
3. **Controlled scalar array for venue facilities (`venues.facilities`)**:
   - Simple facility labels ("Green Room", "PA System", "Loading Dock") are stored as a PostgreSQL `VARCHAR[]` array.
   - This avoids an extra junction table and unnecessary SQL joins for basic amenities tags while supporting PostgreSQL array indexes.
    
4. **Surrogate keys vs Natural keys**:
   - Natural candidate keys like `users(email)` and `setlist_songs(setlist_id, position)` are protected by `UNIQUE` constraints to maintain BCNF.
   - Tables use UUID surrogate primary keys to ensure that updates to email addresses or titles never require cascading foreign key updates.
    
5. **Domain and temporal validation constraints**:
   - Time order checks: `end_time > start_time` on `events`, `bookings`, `equipment_reservations`, and `rehearsals`.
   - Positive numeric checks: `capacity > 0` on `venues`, `duration_seconds > 0` on `songs`, and `total_quantity > 0` on `equipment`.
