-- Add unique constraints for UPSERT operations
-- This fixes the "there is no unique or exclusion constraint matching the ON CONFLICT specification" error

-- Add unique constraint for entity_attributes
ALTER TABLE entity_attributes
ADD CONSTRAINT unique_entity_attribute
UNIQUE (entity_id, attribute_tag);

-- Add unique constraint for entity_equipment
ALTER TABLE entity_equipment
ADD CONSTRAINT unique_entity_equipment
UNIQUE (entity_id, equipment);

-- Add unique constraint for entity_qr_codes
ALTER TABLE entity_qr_codes
ADD CONSTRAINT unique_entity_qr_code
UNIQUE (entity_id, qr_code);

-- Add unique constraint for booking_organizers
ALTER TABLE booking_organizers
ADD CONSTRAINT unique_booking_organizer
UNIQUE (booking_id, user_id);

-- Add unique constraint for booking_participants
ALTER TABLE booking_participants
ADD CONSTRAINT unique_booking_participant
UNIQUE (booking_id, user_id);
