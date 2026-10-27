-- Predicera bokningar för de senaste bokningarna
-- VIKTIGT: MindsDB kräver JOIN-syntax för predictions!
-- 0=Söndag, 1=Måndag, 2=Tisdag, 3=Onsdag, 4=Torsdag, 5=Fredag, 6=Lördag

SELECT
  m.booking_date,
  m.day_of_week,
  m.booking_count as predicted_bookings
FROM booking_forecast AS m
JOIN awaio_postgres.bookings AS t
LIMIT 14
