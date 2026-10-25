-- ---------- B. [BARU] TABEL PELANGGARAN & DENDA ----------
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
