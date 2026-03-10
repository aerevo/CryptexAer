const express = require('express');
const cors = require('cors');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(cors()); // Benarkan semua website (Ticket2U dll) akses

// --- DATABASE SEMENTARA (MEMORY) ---
// Sebab nak jimat & laju, kita simpan dalam RAM je dulu.
// Kalau server restart, data hilang (takpe untuk MVP).
const challenges = new Map();
const sessions = new Map();

// ============================================
// ENDPOINT 1: GET CHALLENGE (Minta Soalan)
// ============================================
// Widget panggil ini untuk dapat nombor target
app.post('/getChallenge', (req, res) => {
    try {
        const nonce = crypto.randomUUID();
        
        // Generate 3 digit rawak (0-9)
        const targetCode = [
            Math.floor(Math.random() * 10),
            Math.floor(Math.random() * 10),
            Math.floor(Math.random() * 10)
        ];

        // Simpan dalam memori (Valid 2 minit)
        challenges.set(nonce, {
            target: targetCode,
            expiry: Date.now() + 120000 // 2 minit
        });

        console.log(`[NEW] Challenge: ${nonce} | Target: ${targetCode}`);

        // Hantar nombor ni ke Widget supaya user boleh tiru
        res.json({
            success: true,
            nonce: nonce,
            targetCode: targetCode 
        });

    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// ENDPOINT 2: ATTEST (Semak Jawapan User)
// ============================================
// Widget hantar jawapan roda kat sini
app.post('/attest', (req, res) => {
    try {
        const { nonce, userAnswer } = req.body;

        const data = challenges.get(nonce);

        // 1. Check wujud tak
        if (!data) {
            return res.status(400).json({ success: false, error: "Expired or Invalid Nonce" });
        }

        // 2. Check expired
        if (Date.now() > data.expiry) {
            challenges.delete(nonce);
            return res.status(400).json({ success: false, error: "Time Limit Exceeded" });
        }

        // 3. Bandingkan Jawapan (Logic Roda)
        // Kita bandingkan string sebab array susah compare terus
        const serverStr = data.target.join('');
        const userStr = userAnswer.join('');

        if (serverStr === userStr) {
            // ✅ LULUS! Generate Token
            const sessionToken = crypto.randomBytes(16).toString('hex');
            
            // Simpan token ni (Valid 10 minit untuk client server check)
            sessions.set(sessionToken, {
                valid: true,
                expiry: Date.now() + 600000
            });

            // Hapus challenge lama (One-time use)
            challenges.delete(nonce);

            console.log(`[PASS] User matched code! Token: ${sessionToken}`);
            res.json({ success: true, token: sessionToken });

        } else {
            // ❌ GAGAL
            console.log(`[FAIL] User: ${userStr} vs Target: ${serverStr}`);
            res.json({ success: false, error: "Incorrect Code" });
        }

    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// ENDPOINT 3: VERIFY (Untuk Server Client)
// ============================================
// Server Ticket2U akan panggil ni untuk confirmkan token tu valid
app.post('/verify', (req, res) => {
    const { token } = req.body;
    const session = sessions.get(token);

    if (session && Date.now() < session.expiry) {
        // Token Valid, buang lepas guna (Anti-Replay)
        sessions.delete(token);
        res.json({ success: true, status: "VERIFIED" });
    } else {
        res.json({ success: false, status: "INVALID_TOKEN" });
    }
});

// --- PEMBERSIHAN AUTOMATIK (GARBAGE COLLECTOR) ---
// Buang data lama setiap 5 minit supaya RAM tak penuh
setInterval(() => {
    const now = Date.now();
    challenges.forEach((val, key) => {
        if (now > val.expiry) challenges.delete(key);
    });
    sessions.forEach((val, key) => {
        if (now > val.expiry) sessions.delete(key);
    });
}, 300000);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🔥 Z-KINETIC DEFENSE RUNNING ON PORT ${PORT}`);
});
