#CREATE INSERT
INSERT INTO Kendaraan (ID_Pengguna, Nomor_Plat, Jenis_Kendaraan, UID_RFID) VALUES
    (1, 'AE 1234 AB', 'Motor', 'RFID-0001'),
    (2, 'AE 5678 CD', 'Mobil', 'RFID-0002'),
    (3, 'AE 9012 EF', 'Motor', 'RFID-0003');

INSERT INTO Slot_Parkir (ID_Area, Nomor_Slot, Posisi) VALUES
    (1, 'A-01', 'selatan'),
    (1, 'A-02', 'utara'),
    (2, 'B-01', 'timur');

INSERT INTO Parkir (ID_Kendaraan, ID_Slot, Waktu_Masuk, Waktu_Keluar) VALUES
    (1, 1, '2026-10-12 07:30:00', NULL),
    (2, 2, '2026-10-12 08:05:00', '2026-10-12 08:10:00'),
    (3, 3, '2026-10-12 08:15:00', NULL);

#READ
SELECT * FROM Kendaraan;

#UPDATE
UPDATE Parkir
   SET Waktu_Keluar = '2026-10-12 09:30:00'
 WHERE No_Log = 1;

#DELETE
DELETE FROM Parkir
 WHERE No_Log = 3;
