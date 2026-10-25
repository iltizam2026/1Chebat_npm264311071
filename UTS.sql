-- =====================================================================
-- 1. PEMODELAN KONSEPTUAL
-- Latar belakang: seiring bertambahnya pengguna, banyak kendaraan
--   parkir sembarangan (di luar slot, melebihi batas waktu, menempati
--   slot reservasi/disabilitas). Pengelola membutuhkan proses baru:
--   petugas mencatat pelanggaran, sistem menentukan denda, pengguna
--   membayar denda, dan kendaraan dengan tunggakan berlebih diblokir.
--
-- Entitas baru:
--   JENIS_PELANGGARAN (ID_Jenis PK, Nama_Pelanggaran, Denda_Standar)
--   PETUGAS_PARKIR    (ID_Petugas PK, ID_Pengguna FK, Shift)
--   PELANGGARAN       (ID_Pelanggaran PK, Waktu_Kejadian, Denda_Dikenakan,
--                      Status_Penanganan, Catatan)
--   PEMBAYARAN_DENDA  (ID_Pembayaran PK, Waktu_Bayar, Jumlah_Bayar,
--                      Metode_Bayar)
--
-- Relasi (ERD):
--   Kendaraan (1) --melakukan--  (N) PELANGGARAN
--   Slot_Parkir (1) --lokasi--   (N) PELANGGARAN   (slot opsional)
--   Jenis_Pelanggaran (1) --mengkategorikan-- (N) PELANGGARAN
--   Petugas_Parkir (1) --mencatat-- (N) PELANGGARAN
--   Tendik (1) --bertugas sebagai-- (0..1) PETUGAS_PARKIR
--   Pelanggaran (1) --dilunasi lewat-- (0..1) PEMBAYARAN_DENDA
--
-- Aturan bisnis:
--   1. Satu pelanggaran = 1 kendaraan + 1 jenis + 1 petugas + 1 waktu.
--   2. Denda tidak boleh negatif; nilainya disalin (snapshot) dari tarif
--      jenis pelanggaran saat dicatat, sehingga perubahan tarif tidak
--      mengubah riwayat.
--   3. Satu pelanggaran hanya boleh dibayar satu kali.
--   4. Jumlah bayar harus sama dengan denda, pembayaran tidak boleh
--      lebih awal dari waktu kejadian, dan pelanggaran berstatus
--      'Dibatalkan' tidak dapat dibayar.
--   5. Kendaraan dengan 3 pelanggaran atau lebih yang belum lunas
--      tidak boleh masuk parkir (diblokir).
--   6. Petugas harus berasal dari Tendik yang terdaftar.
-- =====================================================================

-- =====================================================================
-- 2. PEMODELAN LOGIS
-- Skema relasional:
--   Jenis_Pelanggaran (ID_Jenis, Nama_Pelanggaran, Denda_Standar)
--   Petugas_Parkir    (ID_Petugas, ID_Pengguna*, Shift)
--   Pelanggaran       (ID_Pelanggaran, ID_Kendaraan*, ID_Slot*, ID_Jenis*,
--                      ID_Petugas*, Waktu_Kejadian, Denda_Dikenakan,
--                      Status_Penanganan, Catatan)
--   Pembayaran_Denda  (ID_Pembayaran, ID_Pelanggaran*, Waktu_Bayar,
--                      Jumlah_Bayar, Metode_Bayar)
--   PK : ID_Jenis, ID_Petugas, ID_Pelanggaran, ID_Pembayaran
--   FK : Petugas_Parkir.ID_Pengguna -> Tendik
--        Pelanggaran.ID_Kendaraan -> Kendaraan
--        Pelanggaran.ID_Slot -> Slot_Parkir (NULL boleh)
--        Pelanggaran.ID_Jenis -> Jenis_Pelanggaran
--        Pelanggaran.ID_Petugas -> Petugas_Parkir
--        Pembayaran_Denda.ID_Pelanggaran -> Pelanggaran (UNIQUE, 1:0..1)
--
-- Normalisasi:
--   UNF: Pelanggaran(ID, Nomor_Plat, Nama_Pengguna, {No_HP}, Nomor_Slot,
--        Nama_Area, Nama_Pelanggaran, Denda_Standar, Nama_Petugas, Shift,
--        Waktu_Kejadian, Status, Waktu_Bayar, Jumlah_Bayar, Metode_Bayar)
--   1NF: {No_HP} bernilai banyak dipisah ke Pengguna_Telepon (sudah ada);
--        setiap kolom atomik.
--   2NF: Nomor_Plat bergantung ke ID_Kendaraan; Nomor_Slot dan Nama_Area
--        ke ID_Slot; Nama_Pelanggaran dan Denda_Standar ke ID_Jenis;
--        Nama_Petugas dan Shift ke ID_Petugas. Semuanya dipindah ke tabel
--        masing-masing. Data pembayaran dipisah ke Pembayaran_Denda
--        karena hanya ada setelah pelanggaran dilunasi (menghindari NULL).
--   3NF: Nama_Pengguna bergantung ke ID_Pengguna lewat Kendaraan/Petugas
--        (transitif), Nama_Area lewat ID_Area, sehingga tetap di
--        Pengguna dan Area_Parkir. Pelanggaran hanya menyimpan FK.
--        Catatan: Denda_Dikenakan sengaja disimpan sebagai snapshot
--        historis (nilai saat kejadian), bukan redundansi, karena
--        Denda_Standar dapat berubah di kemudian hari.
-- =====================================================================

-- =====================================================================
-- 3. PEMODELAN FISIK
-- =====================================================================
DROP DATABASE IF EXISTS smart_parking_pelanggaran;
CREATE DATABASE smart_parking_pelanggaran
    CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE smart_parking_pelanggaran;

-- ---------- A. STRUKTUR TABEL (replika kelompok) ----------
CREATE TABLE Area_Parkir (
    ID_Area    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Nama_Area  VARCHAR(50)   NOT NULL,
    Lokasi     VARCHAR(100)  NOT NULL,
    CONSTRAINT pk_area_parkir PRIMARY KEY (ID_Area)
) ENGINE=InnoDB;

CREATE TABLE Slot_Parkir (
    ID_Slot     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    ID_Area     INT UNSIGNED  NOT NULL,
    Nomor_Slot  VARCHAR(10)   NOT NULL,
    Posisi      VARCHAR(50)   NULL,
    CONSTRAINT pk_slot_parkir PRIMARY KEY (ID_Slot),
    CONSTRAINT uq_slot_area_nomor UNIQUE (ID_Area, Nomor_Slot),
    CONSTRAINT fk_slot_area FOREIGN KEY (ID_Area)
        REFERENCES Area_Parkir (ID_Area)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Pengguna (
    ID_Pengguna    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Nama_Pengguna  VARCHAR(100)  NOT NULL,
    CONSTRAINT pk_pengguna PRIMARY KEY (ID_Pengguna)
) ENGINE=InnoDB;

CREATE TABLE Pengguna_Telepon (
    ID_Pengguna  INT UNSIGNED  NOT NULL,
    No_HP        VARCHAR(15)   NOT NULL,
    CONSTRAINT pk_pengguna_telepon PRIMARY KEY (ID_Pengguna, No_HP),
    CONSTRAINT fk_telepon_pengguna FOREIGN KEY (ID_Pengguna)
        REFERENCES Pengguna (ID_Pengguna)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Mahasiswa (
    ID_Pengguna   INT UNSIGNED  NOT NULL,
    NIM           VARCHAR(15)   NOT NULL,
    Program_Studi VARCHAR(60)   NOT NULL,
    Angkatan      YEAR          NOT NULL,
    CONSTRAINT pk_mahasiswa PRIMARY KEY (ID_Pengguna),
    CONSTRAINT uq_mahasiswa_nim UNIQUE (NIM),
    CONSTRAINT fk_mahasiswa_pengguna FOREIGN KEY (ID_Pengguna)
        REFERENCES Pengguna (ID_Pengguna)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Dosen (
    ID_Pengguna       INT UNSIGNED  NOT NULL,
    NIDN              VARCHAR(15)   NOT NULL,
    Jabatan_Akademik  VARCHAR(40)   NULL,
    CONSTRAINT pk_dosen PRIMARY KEY (ID_Pengguna),
    CONSTRAINT uq_dosen_nidn UNIQUE (NIDN),
    CONSTRAINT fk_dosen_pengguna FOREIGN KEY (ID_Pengguna)
        REFERENCES Pengguna (ID_Pengguna)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Tendik (
    ID_Pengguna  INT UNSIGNED  NOT NULL,
    NIP          VARCHAR(20)   NOT NULL,
    Unit_Kerja   VARCHAR(60)   NULL,
    CONSTRAINT pk_tendik PRIMARY KEY (ID_Pengguna),
    CONSTRAINT uq_tendik_nip UNIQUE (NIP),
    CONSTRAINT fk_tendik_pengguna FOREIGN KEY (ID_Pengguna)
        REFERENCES Pengguna (ID_Pengguna)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Kendaraan (
    ID_Kendaraan    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    ID_Pengguna     INT UNSIGNED  NOT NULL,
    Nomor_Plat      VARCHAR(12)   NOT NULL,
    Jenis_Kendaraan ENUM('Motor','Mobil') NOT NULL,
    UID_RFID        VARCHAR(20)   NOT NULL,
    CONSTRAINT pk_kendaraan PRIMARY KEY (ID_Kendaraan),
    CONSTRAINT uq_kendaraan_rfid UNIQUE (UID_RFID),
    CONSTRAINT fk_kendaraan_pengguna FOREIGN KEY (ID_Pengguna)
        REFERENCES Pengguna (ID_Pengguna)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Parkir (
    No_Log         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ID_Kendaraan   INT UNSIGNED    NOT NULL,
    ID_Slot        INT UNSIGNED    NOT NULL,
    Waktu_Masuk    DATETIME        NOT NULL,
    Waktu_Keluar   DATETIME        NULL,
    Durasi_Jam     DECIMAL(6,2) GENERATED ALWAYS AS
                   (TIMESTAMPDIFF(MINUTE, Waktu_Masuk, Waktu_Keluar) / 60) STORED,
    Status_Parkir  VARCHAR(10) GENERATED ALWAYS AS
                   (IF(Waktu_Keluar IS NULL, 'Aktif', 'Selesai')) STORED,
    CONSTRAINT pk_parkir PRIMARY KEY (No_Log),
    CONSTRAINT ck_parkir_waktu CHECK (Waktu_Keluar IS NULL OR Waktu_Keluar >= Waktu_Masuk),
    CONSTRAINT fk_parkir_kendaraan FOREIGN KEY (ID_Kendaraan)
        REFERENCES Kendaraan (ID_Kendaraan)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_parkir_slot FOREIGN KEY (ID_Slot)
        REFERENCES Slot_Parkir (ID_Slot)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------- B. [BARU] TABEL TAMBAHAN: PELANGGARAN & DENDA ----------
CREATE TABLE Jenis_Pelanggaran (
    ID_Jenis         INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Nama_Pelanggaran VARCHAR(60)   NOT NULL,
    Denda_Standar    DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_jenis_pelanggaran PRIMARY KEY (ID_Jenis),
    CONSTRAINT uq_jenis_nama UNIQUE (Nama_Pelanggaran),
    CONSTRAINT ck_jenis_denda CHECK (Denda_Standar >= 0)
) ENGINE=InnoDB;

CREATE TABLE Petugas_Parkir (
    ID_Petugas   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    ID_Pengguna  INT UNSIGNED  NOT NULL,
    Shift        ENUM('Pagi','Siang','Malam') NOT NULL,
    CONSTRAINT pk_petugas PRIMARY KEY (ID_Petugas),
    CONSTRAINT uq_petugas_pengguna UNIQUE (ID_Pengguna),
    CONSTRAINT fk_petugas_tendik FOREIGN KEY (ID_Pengguna)
        REFERENCES Tendik (ID_Pengguna)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Pelanggaran (
    ID_Pelanggaran    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ID_Kendaraan      INT UNSIGNED    NOT NULL,
    ID_Slot           INT UNSIGNED    NULL,
    ID_Jenis          INT UNSIGNED    NOT NULL,
    ID_Petugas        INT UNSIGNED    NOT NULL,
    Waktu_Kejadian    DATETIME        NOT NULL,
    Denda_Dikenakan   DECIMAL(10,2)   NOT NULL DEFAULT 0,
    Status_Penanganan ENUM('Dilaporkan','Diproses','Lunas','Dibatalkan')
                      NOT NULL DEFAULT 'Dilaporkan',
    Catatan           VARCHAR(255)    NULL,
    CONSTRAINT pk_pelanggaran PRIMARY KEY (ID_Pelanggaran),
    CONSTRAINT ck_pelanggaran_denda CHECK (Denda_Dikenakan >= 0),
    CONSTRAINT fk_pelanggaran_kendaraan FOREIGN KEY (ID_Kendaraan)
        REFERENCES Kendaraan (ID_Kendaraan) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pelanggaran_slot FOREIGN KEY (ID_Slot)
        REFERENCES Slot_Parkir (ID_Slot) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pelanggaran_jenis FOREIGN KEY (ID_Jenis)
        REFERENCES Jenis_Pelanggaran (ID_Jenis) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pelanggaran_petugas FOREIGN KEY (ID_Petugas)
        REFERENCES Petugas_Parkir (ID_Petugas) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Pembayaran_Denda (
    ID_Pembayaran   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ID_Pelanggaran  BIGINT UNSIGNED NOT NULL,
    Waktu_Bayar     DATETIME        NOT NULL,
    Jumlah_Bayar    DECIMAL(10,2)   NOT NULL,
    Metode_Bayar    ENUM('Tunai','Transfer','QRIS') NOT NULL,
    CONSTRAINT pk_pembayaran PRIMARY KEY (ID_Pembayaran),
    CONSTRAINT uq_pembayaran_pelanggaran UNIQUE (ID_Pelanggaran),
    CONSTRAINT ck_pembayaran_jumlah CHECK (Jumlah_Bayar > 0),
    CONSTRAINT fk_pembayaran_pelanggaran FOREIGN KEY (ID_Pelanggaran)
        REFERENCES Pelanggaran (ID_Pelanggaran)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------- C. INDEX ----------
CREATE INDEX idx_kendaraan_plat        ON Kendaraan (Nomor_Plat);
CREATE INDEX idx_pelanggaran_kendaraan ON Pelanggaran (ID_Kendaraan, Status_Penanganan);
CREATE INDEX idx_pelanggaran_waktu     ON Pelanggaran (Waktu_Kejadian);

-- ---------- D. TRIGGER & PROSEDUR ----------
DELIMITER $$

-- [BARU] Snapshot denda dari tarif jenis pelanggaran saat dicatat
CREATE TRIGGER trg_pelanggaran_bi BEFORE INSERT ON Pelanggaran
FOR EACH ROW
BEGIN
    SET NEW.Denda_Dikenakan =
        (SELECT Denda_Standar FROM Jenis_Pelanggaran WHERE ID_Jenis = NEW.ID_Jenis);
END$$

-- [BARU] Validasi pembayaran denda
CREATE TRIGGER trg_pembayaran_bi BEFORE INSERT ON Pembayaran_Denda
FOR EACH ROW
BEGIN
    DECLARE v_denda  DECIMAL(10,2);
    DECLARE v_status VARCHAR(12);
    DECLARE v_waktu  DATETIME;

    SELECT Denda_Dikenakan, Status_Penanganan, Waktu_Kejadian
      INTO v_denda, v_status, v_waktu
      FROM Pelanggaran WHERE ID_Pelanggaran = NEW.ID_Pelanggaran;

    IF v_status = 'Dibatalkan' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pelanggaran yang dibatalkan tidak dapat dibayar';
    END IF;
    IF NEW.Jumlah_Bayar <> v_denda THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Jumlah bayar harus sama dengan denda';
    END IF;
    IF NEW.Waktu_Bayar < v_waktu THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Waktu bayar tidak boleh sebelum waktu kejadian';
    END IF;
END$$

-- [BARU] Setelah dibayar, status pelanggaran otomatis menjadi Lunas
CREATE TRIGGER trg_pembayaran_ai AFTER INSERT ON Pembayaran_Denda
FOR EACH ROW
BEGIN
    UPDATE Pelanggaran
       SET Status_Penanganan = 'Lunas'
     WHERE ID_Pelanggaran = NEW.ID_Pelanggaran;
END$$

-- [BARU] Blokir kendaraan dengan >= 3 pelanggaran belum lunas
CREATE TRIGGER trg_parkir_bi BEFORE INSERT ON Parkir
FOR EACH ROW
BEGIN
    IF (SELECT COUNT(*) FROM Pelanggaran
         WHERE ID_Kendaraan = NEW.ID_Kendaraan
           AND Status_Penanganan IN ('Dilaporkan','Diproses')) >= 3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Kendaraan diblokir: 3 pelanggaran atau lebih belum lunas';
    END IF;
END$$

-- [BARU] Prosedur: total tunggakan per kendaraan
CREATE PROCEDURE sp_tunggakan_kendaraan(IN p_id_kendaraan INT UNSIGNED)
BEGIN
    SELECT k.Nomor_Plat,
           COUNT(p.ID_Pelanggaran)               AS Jumlah_Pelanggaran,
           IFNULL(SUM(p.Denda_Dikenakan), 0)     AS Total_Tunggakan
      FROM Kendaraan k
      LEFT JOIN Pelanggaran p
             ON p.ID_Kendaraan = k.ID_Kendaraan
            AND p.Status_Penanganan IN ('Dilaporkan','Diproses')
     WHERE k.ID_Kendaraan = p_id_kendaraan
     GROUP BY k.Nomor_Plat;
END$$

DELIMITER ;

-- ---------- E. DATA UJI ----------
INSERT INTO Area_Parkir (Nama_Area, Lokasi) VALUES
    ('Parkir Gedung A', 'Depan Gedung Rektorat'),
    ('Parkir Gedung B', 'Samping Laboratorium');

INSERT INTO Slot_Parkir (ID_Area, Nomor_Slot, Posisi) VALUES
    (1,'A-01','Barat'),(1,'A-02','Barat'),(1,'A-03','Timur'),(1,'A-04','Timur'),
    (2,'B-01','Utara'),(2,'B-02','Utara'),(2,'B-03','Selatan');

INSERT INTO Pengguna (Nama_Pengguna) VALUES
    ('Vicky Aditya Surya Samudra'),('Budi Santoso'),('Siti Rahma'),('Rudi Hartono');
INSERT INTO Pengguna_Telepon VALUES (1,'081234567890'),(2,'082233334444'),(4,'087755556666');
INSERT INTO Mahasiswa VALUES (1,'264311086','Teknik Informatika',2026);
INSERT INTO Dosen     VALUES (2,'0712058801','Lektor');
INSERT INTO Mahasiswa VALUES (3,'264311099','Sistem Informasi',2026);
INSERT INTO Tendik    VALUES (4,'198501012010011001','Unit Keamanan');

INSERT INTO Kendaraan (ID_Pengguna, Nomor_Plat, Jenis_Kendaraan, UID_RFID) VALUES
    (1,'AE 1234 AB','Motor','RFID-0001'),
    (2,'AE 5678 CD','Mobil','RFID-0002'),
    (3,'AE 9012 EF','Motor','RFID-0003');

INSERT INTO Parkir (ID_Kendaraan, ID_Slot, Waktu_Masuk, Waktu_Keluar) VALUES
    (1,1,'2026-10-12 07:00:00',NULL),
    (2,2,'2026-10-12 07:05:00','2026-10-12 08:00:00'),
    (3,5,'2026-10-12 07:10:00',NULL);

INSERT INTO Jenis_Pelanggaran (Nama_Pelanggaran, Denda_Standar) VALUES
    ('Parkir di luar slot',        20000),
    ('Melebihi batas waktu',       15000),
    ('Menempati slot khusus',      50000);

INSERT INTO Petugas_Parkir (ID_Pengguna, Shift) VALUES (4,'Pagi');

-- Pelanggaran 1-2: akan diuji pembayaran. Pelanggaran 3-5: kendaraan 3 (menunggak).
-- Pelanggaran 6: dibatalkan.
INSERT INTO Pelanggaran (ID_Kendaraan, ID_Slot, ID_Jenis, ID_Petugas, Waktu_Kejadian, Catatan) VALUES
    (1, 1, 1, 1, '2026-10-13 09:00:00', 'Roda menutup slot sebelah'),
    (2, 2, 2, 1, '2026-10-13 10:30:00', 'Parkir lebih dari batas'),
    (3, 5, 1, 1, '2026-10-14 08:00:00', NULL),
    (3, 5, 2, 1, '2026-10-15 08:00:00', NULL),
    (3, 7, 3, 1, '2026-10-16 08:00:00', 'Menempati slot khusus disabilitas');
INSERT INTO Pelanggaran (ID_Kendaraan, ID_Slot, ID_Jenis, ID_Petugas, Waktu_Kejadian, Status_Penanganan, Catatan) VALUES
    (2, NULL, 1, 1, '2026-10-17 09:00:00', 'Dibatalkan', 'Salah catat plat');

-- Pembayaran sah (status pelanggaran 1 otomatis menjadi Lunas)
INSERT INTO Pembayaran_Denda (ID_Pelanggaran, Waktu_Bayar, Jumlah_Bayar, Metode_Bayar) VALUES
    (1, '2026-10-14 10:00:00', 20000, 'QRIS');

-- ---------- F. KUERI BUKTI ----------
-- (1) Daftar pelanggaran lengkap beserta status bayar
SELECT p.ID_Pelanggaran, u.Nama_Pengguna, k.Nomor_Plat, j.Nama_Pelanggaran,
       a.Nama_Area, s.Nomor_Slot, p.Waktu_Kejadian, p.Denda_Dikenakan,
       p.Status_Penanganan, b.Waktu_Bayar, b.Metode_Bayar
  FROM Pelanggaran p
  JOIN Kendaraan        k ON k.ID_Kendaraan = p.ID_Kendaraan
  JOIN Pengguna         u ON u.ID_Pengguna  = k.ID_Pengguna
  JOIN Jenis_Pelanggaran j ON j.ID_Jenis    = p.ID_Jenis
  LEFT JOIN Slot_Parkir s ON s.ID_Slot      = p.ID_Slot
  LEFT JOIN Area_Parkir a ON a.ID_Area      = s.ID_Area
  LEFT JOIN Pembayaran_Denda b ON b.ID_Pelanggaran = p.ID_Pelanggaran
 ORDER BY p.Waktu_Kejadian;

-- (2) Total tunggakan per kendaraan
CALL sp_tunggakan_kendaraan(3);

-- (3) Bukti index
EXPLAIN SELECT * FROM Pelanggaran
 WHERE ID_Kendaraan = 3 AND Status_Penanganan = 'Dilaporkan';

-- (4) Bukti constraint: setiap perintah di bawah HARUS GAGAL
INSERT INTO Pembayaran_Denda (ID_Pelanggaran, Waktu_Bayar, Jumlah_Bayar, Metode_Bayar)
VALUES (1, '2026-10-15 10:00:00', 20000, 'Tunai');   -- dibayar dua kali (UNIQUE)
INSERT INTO Pembayaran_Denda (ID_Pelanggaran, Waktu_Bayar, Jumlah_Bayar, Metode_Bayar)
VALUES (2, '2026-10-15 10:00:00', 5000, 'Tunai');    -- jumlah tidak sesuai denda
INSERT INTO Pembayaran_Denda (ID_Pelanggaran, Waktu_Bayar, Jumlah_Bayar, Metode_Bayar)
VALUES (6, '2026-10-18 10:00:00', 20000, 'QRIS');    -- pelanggaran dibatalkan
INSERT INTO Pembayaran_Denda (ID_Pelanggaran, Waktu_Bayar, Jumlah_Bayar, Metode_Bayar)
VALUES (2, '2026-10-01 10:00:00', 15000, 'Transfer');-- bayar sebelum kejadian
INSERT INTO Parkir (ID_Kendaraan, ID_Slot, Waktu_Masuk)
VALUES (3, 6, '2026-10-19 07:00:00');                -- kendaraan diblokir (3 tunggakan)
INSERT INTO Jenis_Pelanggaran (Nama_Pelanggaran, Denda_Standar)
VALUES ('Tes denda negatif', -1000);                 -- denda negatif (CHECK)
INSERT INTO Pelanggaran (ID_Kendaraan, ID_Slot, ID_Jenis, ID_Petugas, Waktu_Kejadian)
VALUES (1, 1, 1, 99, '2026-10-20 08:00:00');         -- petugas tidak ada (FK)
