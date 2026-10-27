-- Awaio Database Schema for PostgreSQL
-- Database for managing bookings and entities

-- Communities table
CREATE TABLE IF NOT EXISTS communities (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_communities_name ON communities(name);

-- Users table (referenced by bookings)
-- When ANONYMIZE_USERS=true, `id` is HMAC-SHA256(ANONYMIZE_SALT, awaio_user_id)[:24]
-- and all FK references (bookings.owner_id, booking_organizers/participants.user_id)
-- use the same hashed id. The raw Awaio user_id is never stored.
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(50) PRIMARY KEY,
    email VARCHAR(255),
    name VARCHAR(255),
    display_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL;

-- Entities table (spaces/resources that can be booked)
CREATE TABLE IF NOT EXISTS entities (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    parent_id VARCHAR(50),
    community_id VARCHAR(50) NOT NULL,
    main_tag VARCHAR(100),
    group_tag VARCHAR(100),
    capacity_normal INT,
    capacity_max INT,
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_postal_code VARCHAR(20),
    address_country VARCHAR(100),
    geo_latitude DECIMAL(10, 8),
    geo_longitude DECIMAL(11, 8),
    device_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_entities_parent FOREIGN KEY (parent_id) REFERENCES entities(id) ON DELETE SET NULL,
    CONSTRAINT fk_entities_community FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_entities_community ON entities(community_id);
CREATE INDEX IF NOT EXISTS idx_entities_parent ON entities(parent_id);
CREATE INDEX IF NOT EXISTS idx_entities_main_tag ON entities(main_tag);
CREATE INDEX IF NOT EXISTS idx_entities_group_tag ON entities(group_tag);

-- Entity attributes (tags)
CREATE TABLE IF NOT EXISTS entity_attributes (
    id SERIAL PRIMARY KEY,
    entity_id VARCHAR(50) NOT NULL,
    attribute_tag VARCHAR(100) NOT NULL,
    CONSTRAINT fk_entity_attributes_entity FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    CONSTRAINT unique_entity_attribute UNIQUE (entity_id, attribute_tag)
);

CREATE INDEX IF NOT EXISTS idx_entity_attributes_entity ON entity_attributes(entity_id);
CREATE INDEX IF NOT EXISTS idx_entity_attributes_tag ON entity_attributes(attribute_tag);

-- Entity equipment
CREATE TABLE IF NOT EXISTS entity_equipment (
    id SERIAL PRIMARY KEY,
    entity_id VARCHAR(50) NOT NULL,
    equipment VARCHAR(255) NOT NULL,
    CONSTRAINT fk_entity_equipment_entity FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    CONSTRAINT unique_entity_equipment UNIQUE (entity_id, equipment)
);

CREATE INDEX IF NOT EXISTS idx_entity_equipment_entity ON entity_equipment(entity_id);

-- Entity photos
CREATE TABLE IF NOT EXISTS entity_photos (
    id SERIAL PRIMARY KEY,
    entity_id VARCHAR(50) NOT NULL,
    photo_url TEXT NOT NULL,
    display_order INT DEFAULT 0,
    CONSTRAINT fk_entity_photos_entity FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_entity_photos_entity ON entity_photos(entity_id);

-- Entity QR codes
CREATE TABLE IF NOT EXISTS entity_qr_codes (
    id SERIAL PRIMARY KEY,
    entity_id VARCHAR(50) NOT NULL,
    qr_code VARCHAR(255) NOT NULL,
    CONSTRAINT fk_entity_qr_codes_entity FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    CONSTRAINT unique_entity_qr_code UNIQUE (entity_id, qr_code)
);

CREATE INDEX IF NOT EXISTS idx_entity_qr_codes_entity ON entity_qr_codes(entity_id);

-- Booking rules for entities
CREATE TABLE IF NOT EXISTS booking_rules (
    id SERIAL PRIMARY KEY,
    entity_id VARCHAR(50) NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    rule_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_booking_rules_entity FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_booking_rules_entity ON booking_rules(entity_id);

-- Calendar events
-- Only the id is stored. Title/description are intentionally omitted because
-- they can contain personal names / free text from calendar integrations.
CREATE TABLE IF NOT EXISTS calendar_events (
    id VARCHAR(50) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create booking status type
DO $$ BEGIN
    CREATE TYPE booking_status AS ENUM ('reserved', 'obsolete');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
-- 'blocked': long admin bookings (e.g. election office), excluded from
-- utilisation by every status = 'reserved' filter. Set by fetch_bookings.py.
ALTER TYPE booking_status ADD VALUE IF NOT EXISTS 'blocked';

-- Bookings table (main table for reservations)
CREATE TABLE IF NOT EXISTS bookings (
    id VARCHAR(50) PRIMARY KEY,
    calendar_event_id VARCHAR(50),
    owner_id VARCHAR(50) NOT NULL,
    community_id VARCHAR(50) NOT NULL,
    entity_id VARCHAR(50) NOT NULL,
    category VARCHAR(100),
    status booking_status NOT NULL DEFAULT 'reserved',
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    cancelled BOOLEAN DEFAULT FALSE,
    ended_early BOOLEAN DEFAULT FALSE,
    is_admin BOOLEAN DEFAULT FALSE,
    group_tag VARCHAR(100),
    main_tag VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bookings_calendar FOREIGN KEY (calendar_event_id) REFERENCES calendar_events(id) ON DELETE SET NULL,
    CONSTRAINT fk_bookings_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_bookings_community FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
    CONSTRAINT fk_bookings_entity FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_bookings_owner ON bookings(owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_community ON bookings(community_id);
CREATE INDEX IF NOT EXISTS idx_bookings_entity ON bookings(entity_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_start_time ON bookings(start_time);
CREATE INDEX IF NOT EXISTS idx_bookings_end_time ON bookings(end_time);
CREATE INDEX IF NOT EXISTS idx_bookings_date_range ON bookings(start_time, end_time);

-- Booking organizers (many-to-many relationship)
CREATE TABLE IF NOT EXISTS booking_organizers (
    id SERIAL PRIMARY KEY,
    booking_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    CONSTRAINT fk_booking_organizers_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    CONSTRAINT fk_booking_organizers_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT unique_booking_organizer UNIQUE (booking_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_booking_organizers_booking ON booking_organizers(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_organizers_user ON booking_organizers(user_id);

-- Booking participants (many-to-many relationship)
CREATE TABLE IF NOT EXISTS booking_participants (
    id SERIAL PRIMARY KEY,
    booking_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    CONSTRAINT fk_booking_participants_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    CONSTRAINT fk_booking_participants_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT unique_booking_participant UNIQUE (booking_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_booking_participants_booking ON booking_participants(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_participants_user ON booking_participants(user_id);

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_communities_updated_at BEFORE UPDATE ON communities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_entities_updated_at BEFORE UPDATE ON entities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_calendar_events_updated_at BEFORE UPDATE ON calendar_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create views for common queries

-- View: Active bookings with entity and owner details
CREATE OR REPLACE VIEW active_bookings AS
SELECT
    b.id,
    b.calendar_event_id,
    b.start_time,
    b.end_time,
    b.status,
    b.cancelled,
    b.ended_early,
    b.group_tag,
    b.main_tag,
    u.id AS owner_id,
    u.email AS owner_email,
    u.name AS owner_name,
    e.id AS entity_id,
    e.name AS entity_name,
    e.main_tag AS entity_main_tag,
    e.group_tag AS entity_group_tag,
    c.id AS community_id,
    c.name AS community_name
FROM bookings b
INNER JOIN users u ON b.owner_id = u.id
INNER JOIN entities e ON b.entity_id = e.id
INNER JOIN communities c ON b.community_id = c.id
WHERE b.status = 'reserved'
  AND b.cancelled = FALSE
  AND b.end_time > NOW();

-- View: Entity availability summary
CREATE OR REPLACE VIEW entity_booking_summary AS
SELECT
    e.id AS entity_id,
    e.name AS entity_name,
    e.group_tag,
    e.main_tag,
    c.name AS community_name,
    COUNT(b.id) AS total_bookings,
    SUM(CASE WHEN b.status = 'reserved' AND b.cancelled = FALSE THEN 1 ELSE 0 END) AS active_bookings,
    MAX(b.end_time) AS last_booking_end
FROM entities e
LEFT JOIN bookings b ON e.id = b.entity_id
LEFT JOIN communities c ON e.community_id = c.id
GROUP BY e.id, e.name, e.group_tag, e.main_tag, c.name;

-- Function: Find available entities in a time slot
CREATE OR REPLACE FUNCTION find_available_entities(
    p_community_id VARCHAR(50),
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP,
    p_group_tag VARCHAR(100) DEFAULT NULL
)
RETURNS TABLE (
    id VARCHAR(50),
    name VARCHAR(255),
    main_tag VARCHAR(100),
    group_tag VARCHAR(100),
    capacity_normal INT,
    capacity_max INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        e.name,
        e.main_tag,
        e.group_tag,
        e.capacity_normal,
        e.capacity_max
    FROM entities e
    WHERE e.community_id = p_community_id
      AND (p_group_tag IS NULL OR e.group_tag = p_group_tag)
      AND e.id NOT IN (
          SELECT b.entity_id
          FROM bookings b
          WHERE b.status = 'reserved'
            AND b.cancelled = FALSE
            AND (
                (b.start_time <= p_start_time AND b.end_time > p_start_time)
                OR (b.start_time < p_end_time AND b.end_time >= p_end_time)
                OR (b.start_time >= p_start_time AND b.end_time <= p_end_time)
            )
      )
    ORDER BY e.name;
END;
$$ LANGUAGE plpgsql;

-- Function: Get booking conflicts
CREATE OR REPLACE FUNCTION check_booking_conflicts(
    p_entity_id VARCHAR(50),
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP,
    p_exclude_booking_id VARCHAR(50) DEFAULT NULL
)
RETURNS TABLE (
    id VARCHAR(50),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    status booking_status,
    owner_email VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id,
        b.start_time,
        b.end_time,
        b.status,
        u.email AS owner_email
    FROM bookings b
    INNER JOIN users u ON b.owner_id = u.id
    WHERE b.entity_id = p_entity_id
      AND b.status = 'reserved'
      AND b.cancelled = FALSE
      AND (p_exclude_booking_id IS NULL OR b.id != p_exclude_booking_id)
      AND (
          (b.start_time <= p_start_time AND b.end_time > p_start_time)
          OR (b.start_time < p_end_time AND b.end_time >= p_end_time)
          OR (b.start_time >= p_start_time AND b.end_time <= p_end_time)
      )
    ORDER BY b.start_time;
END;
$$ LANGUAGE plpgsql;

-- Insert example data (optional)
INSERT INTO communities (id, name) VALUES ('OlnrwKaefGc2C2Z9Znzv', 'Example Community')
ON CONFLICT (id) DO NOTHING;

INSERT INTO users (id, email, name) VALUES
    ('example-user-1', 'user1@example.com', 'User One'),
    ('example-user-2', 'user2@example.com', 'User Two')
ON CONFLICT (id) DO NOTHING;

INSERT INTO entities (id, name, community_id, main_tag, group_tag, capacity_normal, capacity_max) VALUES
    ('example-desk-1', 'Desk 1', 'OlnrwKaefGc2C2Z9Znzv', 'desk', 'desk', 1, 1),
    ('example-room-1', 'Teams Room', 'OlnrwKaefGc2C2Z9Znzv', 'teams room', 'room', 6, 8)
ON CONFLICT (id) DO NOTHING;
