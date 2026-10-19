SELECT
	k.Nomor_Plat,
	k.Jenis_Kendaraan,
	COUNT(p.No_Log)    AS jumlah_parkir,
	SUM(p.Durasi_Jam)  AS total_durasi_jam
	FROM Parkir p
	JOIN Kendaraan k ON p.ID_Kendaraan = k.ID_Kendaraan
	WHERE p.Status_Parkir = 'Selesai'
GROUP BY k.ID_Kendaraan, k.Nomor_Plat, k.Jenis_Kendaraan;
