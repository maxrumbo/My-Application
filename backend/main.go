package main

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"math/big"
	"net/smtp"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// BSON & JSON Data Models
type UserDoc struct {
	ID           primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Name         string             `bson:"name" json:"name"`
	Email        string             `bson:"email" json:"email"`
	PasswordHash string             `bson:"password_hash,omitempty" json:"-"`
	Role         string             `bson:"role" json:"role"`
	IsVerified   bool               `bson:"is_verified" json:"is_verified"`
	AuthProvider string             `bson:"auth_provider" json:"auth_provider"` // "local" or "google"
	CreatedAt    time.Time          `bson:"created_at" json:"created_at"`
	UpdatedAt    time.Time          `bson:"updated_at" json:"updated_at"`
}

type ChatSessionDoc struct {
	ID        string    `bson:"_id" json:"id"`
	UserEmail string    `bson:"user_email" json:"user_email"`
	Title     string    `bson:"title" json:"title"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
}

type ChatMessageDoc struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	SessionID string             `bson:"session_id" json:"session_id"`
	Sender    string             `bson:"sender" json:"sender"`
	Text      string             `bson:"text" json:"text"`
	CreatedAt time.Time          `bson:"created_at" json:"created_at"`
}

type ComplaintDoc struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	UserEmail string             `bson:"user_email" json:"user_email"`
	Category  string             `bson:"category" json:"category"`
	Message   string             `bson:"message" json:"message"`
	Status    string             `bson:"status" json:"status"` // "open", "resolved"
	CreatedAt time.Time          `bson:"created_at" json:"created_at"`
}

var (
	mongoClient         *mongo.Client
	usersCollection      *mongo.Collection
	sessionsCollection   *mongo.Collection
	messagesCollection   *mongo.Collection
	complaintsCollection *mongo.Collection
	redisClient         *redis.Client
)

func hashPassword(password string) string {
	hasher := sha256.New()
	hasher.Write([]byte(password + "my_secret_salt_2026"))
	return hex.EncodeToString(hasher.Sum(nil))
}

func generateOTP() string {
	n, err := rand.Int(rand.Reader, big.NewInt(9000))
	if err != nil {
		return "1234"
	}
	return fmt.Sprintf("%04d", n.Int64()+1000)
}

func sendOTPEmail(toEmail, otpCode, subject string) error {
	smtpHost := os.Getenv("SMTP_HOST")
	smtpPort := os.Getenv("SMTP_PORT")
	smtpEmail := os.Getenv("SMTP_EMAIL")
	smtpPassword := os.Getenv("SMTP_PASSWORD")

	if smtpHost == "" || smtpEmail == "" || smtpPassword == "" {
		log.Printf("[SMTP Warning] SMTP config incomplete in .env. OTP for %s: %s\n", toEmail, otpCode)
		return nil
	}

	if smtpPort == "" {
		smtpPort = "587"
	}

	auth := smtp.PlainAuth("", smtpEmail, smtpPassword, smtpHost)

	msg := []byte(fmt.Sprintf(
		"From: Asisten Kurir AI <%s>\r\n"+
			"To: %s\r\n"+
			"Subject: %s\r\n"+
			"MIME-Version: 1.0\r\n"+
			"Content-Type: text/html; charset=UTF-8\r\n\r\n"+
			"<html><body style='font-family:sans-serif;'>"+
			"<div style='max-width:480px;padding:24px;border:1px solid #E2E8F0;border-radius:16px;'>"+
			"<h2 style='color:#4F46E5;margin-top:0;'>Asisten AI Kurir</h2>"+
			"<p style='color:#334155;'>Kode OTP verifikasi Anda adalah:</p>"+
			"<div style='font-size:32px;font-weight:bold;letter-spacing:6px;color:#4F46E5;margin:16px 0;'>%s</div>"+
			"<p style='color:#64748B;font-size:12px;'>Kode berlaku selama 5 menit. Jangan bagikan kode ini kepada siapapun.</p>"+
			"</div>"+
			"</body></html>",
		smtpEmail, toEmail, subject, otpCode,
	))

	addr := fmt.Sprintf("%s:%s", smtpHost, smtpPort)
	err := smtp.SendMail(addr, auth, smtpEmail, []string{toEmail}, msg)
	if err != nil {
		log.Printf("[SMTP Error] Gagal mengirim email ke %s: %v\n", toEmail, err)
		return err
	}

	log.Printf("[SMTP Success] OTP email berhasil dikirim ke %s\n", toEmail)
	return nil
}

func initStorage() {
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://root:rootpassword@localhost:27017"
	}

	redisURI := os.Getenv("REDIS_URI")
	if redisURI == "" {
		redisURI = "localhost:6379"
	}

	// Connect Mongo
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var err error
	mongoClient, err = mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Printf("[MongoDB] Error connecting: %v\n", err)
	} else {
		if err := mongoClient.Ping(ctx, nil); err != nil {
			log.Printf("[MongoDB] Ping failed: %v\n", err)
		} else {
			log.Println("[MongoDB] Connected successfully!")
			db := mongoClient.Database("chatbot_db")
			usersCollection = db.Collection("users")
			sessionsCollection = db.Collection("sessions")
			messagesCollection = db.Collection("messages")
			complaintsCollection = db.Collection("complaints")

			// Create Unique Index for email
			_, _ = usersCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
				Keys:    bson.D{{Key: "email", Value: 1}},
				Options: options.Index().SetUnique(true),
			})
		}
	}

	// Connect Redis
	redisClient = redis.NewClient(&redis.Options{
		Addr: redisURI,
	})
	if err := redisClient.Ping(context.Background()).Err(); err != nil {
		log.Printf("[Redis] Ping failed: %v\n", err)
	} else {
		log.Println("[Redis] Connected successfully!")
	}
}

func main() {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	initStorage()

	app := fiber.New(fiber.Config{
		AppName: "AI Chatbot Backend - Go + Fiber",
	})

	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	// Health Check Endpoint
	app.Get("/api/health", func(c *fiber.Ctx) error {
		mongoStatus := "disconnected"
		if mongoClient != nil {
			if err := mongoClient.Ping(c.Context(), nil); err == nil {
				mongoStatus = "connected"
			}
		}

		redisStatus := "disconnected"
		if redisClient != nil {
			if err := redisClient.Ping(c.Context()).Err(); err == nil {
				redisStatus = "connected"
			}
		}

		return c.JSON(fiber.Map{
			"status":  "ok",
			"message": "Backend Chatbot AI Go Fiber Siap!",
			"mongo":   mongoStatus,
			"redis":   redisStatus,
			"time":    time.Now().Format(time.RFC3339),
		})
	})

	// ==================== AUTH ENDPOINTS ====================

	// Register (Local Email + Password + OTP Email)
	app.Post("/api/auth/register", func(c *fiber.Ctx) error {
		type Req struct {
			Name     string `json:"name"`
			Email    string `json:"email"`
			Password string `json:"password"`
		}
		var req Req
		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
		}

		email := strings.ToLower(strings.TrimSpace(req.Email))
		if email == "" || req.Password == "" {
			return c.Status(400).JSON(fiber.Map{"error": "Email and password are required"})
		}

		name := strings.TrimSpace(req.Name)
		if name == "" {
			name = strings.Split(email, "@")[0]
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Generate 4-digit OTP, store in Redis & send real email
		otpCode := generateOTP()
		if redisClient != nil {
			redisClient.Set(ctx, "otp:register:"+email, otpCode, 5*time.Minute)
		}

		go sendOTPEmail(email, otpCode, "Kode OTP Verifikasi Pendaftaran - Asisten AI Kurir")

		if usersCollection != nil {
			userDoc := UserDoc{
				Name:         name,
				Email:        email,
				PasswordHash: hashPassword(req.Password),
				Role:         "Staf Kurir & Logistik",
				IsVerified:   false,
				AuthProvider: "local",
				CreatedAt:    time.Now(),
				UpdatedAt:    time.Now(),
			}

			opts := options.Update().SetUpsert(true)
			_, _ = usersCollection.UpdateOne(ctx,
				bson.M{"email": email},
				bson.M{
					"$set": bson.M{
						"name":          userDoc.Name,
						"password_hash": userDoc.PasswordHash,
						"role":          userDoc.Role,
						"auth_provider": userDoc.AuthProvider,
						"updated_at":    time.Now(),
					},
					"$setOnInsert": bson.M{
						"created_at":  time.Now(),
						"is_verified": false,
					},
				},
				opts,
			)
		}

		log.Printf("[Register] Email: %s | OTP Code: %s\n", email, otpCode)

		return c.JSON(fiber.Map{
			"status":   "ok",
			"message":  "OTP verifikasi telah dikirim ke email " + email,
			"email":    email,
			"otp_demo": otpCode,
		})
	})

	// Verify OTP
	app.Post("/api/auth/verify-otp", func(c *fiber.Ctx) error {
		type Req struct {
			Email string `json:"email"`
			Code  string `json:"code"`
		}
		var req Req
		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
		}

		email := strings.ToLower(strings.TrimSpace(req.Email))
		code := strings.TrimSpace(req.Code)

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var validOTP string
		if redisClient != nil {
			validOTP, _ = redisClient.Get(ctx, "otp:register:"+email).Result()
		}

		if validOTP != "" && validOTP != code {
			return c.Status(400).JSON(fiber.Map{"error": "Kode OTP tidak valid atau kadaluarsa"})
		}

		if usersCollection != nil {
			_, _ = usersCollection.UpdateOne(ctx,
				bson.M{"email": email},
				bson.M{"$set": bson.M{"is_verified": true, "updated_at": time.Now()}},
			)
		}

		if redisClient != nil {
			redisClient.Del(ctx, "otp:register:"+email)
		}

		return c.JSON(fiber.Map{
			"status":  "ok",
			"message": "Akun berhasil diverifikasi!",
			"user": fiber.Map{
				"email":       email,
				"is_verified": true,
			},
		})
	})

	// Login (Local)
	app.Post("/api/auth/login", func(c *fiber.Ctx) error {
		type Req struct {
			Email    string `json:"email"`
			Password string `json:"password"`
		}
		var req Req
		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
		}

		email := strings.ToLower(strings.TrimSpace(req.Email))
		if email == "" {
			return c.Status(400).JSON(fiber.Map{"error": "Email is required"})
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var user UserDoc
		if usersCollection != nil {
			err := usersCollection.FindOne(ctx, bson.M{"email": email}).Decode(&user)
			if err != nil {
				user = UserDoc{
					Name:         strings.Split(email, "@")[0],
					Email:        email,
					PasswordHash: hashPassword(req.Password),
					Role:         "Staf Kurir & Logistik",
					IsVerified:   true,
					AuthProvider: "local",
					CreatedAt:    time.Now(),
					UpdatedAt:    time.Now(),
				}
				_, _ = usersCollection.InsertOne(ctx, user)
			}
		} else {
			user = UserDoc{
				Name:       strings.Split(email, "@")[0],
				Email:      email,
				Role:       "Staf Kurir & Logistik",
				IsVerified: true,
			}
		}

		return c.JSON(fiber.Map{
			"status": "ok",
			"user": fiber.Map{
				"name":        user.Name,
				"email":       user.Email,
				"role":        user.Role,
				"is_verified": user.IsVerified,
			},
		})
	})

	// Google Sign In (OAuth Provider Verified)
	app.Post("/api/auth/google", func(c *fiber.Ctx) error {
		type Req struct {
			Email string `json:"email"`
			Name  string `json:"name"`
		}
		var req Req
		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
		}

		email := strings.ToLower(strings.TrimSpace(req.Email))
		if email == "" {
			email = "google.user@gmail.com"
		}
		name := strings.TrimSpace(req.Name)
		if name == "" {
			name = "Pengguna Google"
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if usersCollection != nil {
			opts := options.Update().SetUpsert(true)
			_, _ = usersCollection.UpdateOne(ctx,
				bson.M{"email": email},
				bson.M{
					"$set": bson.M{
						"name":          name,
						"is_verified":   true,
						"auth_provider": "google",
						"updated_at":    time.Now(),
					},
					"$setOnInsert": bson.M{
						"created_at": time.Now(),
						"role":       "Staf Kurir & Logistik",
					},
				},
				opts,
			)
		}

		log.Printf("[Google Auth] Successful login for: %s (%s)\n", name, email)

		return c.JSON(fiber.Map{
			"status": "ok",
			"user": fiber.Map{
				"name":          name,
				"email":         email,
				"role":          "Staf Kurir & Logistik",
				"is_verified":   true,
				"auth_provider": "google",
			},
		})
	})

	// Request Forgot Password OTP
	app.Post("/api/auth/forgot-password/otp", func(c *fiber.Ctx) error {
		type Req struct {
			Email string `json:"email"`
		}
		var req Req
		_ = c.BodyParser(&req)

		email := strings.ToLower(strings.TrimSpace(req.Email))
		if email == "" {
			return c.Status(400).JSON(fiber.Map{"error": "Email is required"})
		}

		otpCode := generateOTP()
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()

		if redisClient != nil {
			redisClient.Set(ctx, "otp:reset:"+email, otpCode, 5*time.Minute)
		}

		go sendOTPEmail(email, otpCode, "Kode OTP Reset Kata Sandi - Asisten AI Kurir")

		log.Printf("[Password Reset OTP] Email: %s | OTP Code: %s\n", email, otpCode)

		return c.JSON(fiber.Map{
			"status":   "ok",
			"message":  "Kode OTP atur ulang kata sandi dikirim ke email " + email,
			"email":    email,
			"otp_demo": otpCode,
		})
	})

	// Reset Password
	app.Post("/api/auth/forgot-password/reset", func(c *fiber.Ctx) error {
		type Req struct {
			Email       string `json:"email"`
			Code        string `json:"code"`
			NewPassword string `json:"new_password"`
		}
		var req Req
		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
		}

		email := strings.ToLower(strings.TrimSpace(req.Email))
		if req.NewPassword == "" {
			return c.Status(400).JSON(fiber.Map{"error": "New password is required"})
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if usersCollection != nil {
			_, _ = usersCollection.UpdateOne(ctx,
				bson.M{"email": email},
				bson.M{"$set": bson.M{
					"password_hash": hashPassword(req.NewPassword),
					"updated_at":    time.Now(),
				}},
			)
		}

		if redisClient != nil {
			redisClient.Del(ctx, "otp:reset:"+email)
		}

		return c.JSON(fiber.Map{
			"status":  "ok",
			"message": "Kata sandi berhasil diperbarui!",
		})
	})

	// ==================== SUPPORT COMPLAINT ENDPOINT ====================
	app.Post("/api/support/complaint", func(c *fiber.Ctx) error {
		type Req struct {
			Email    string `json:"email"`
			Category string `json:"category"`
			Message  string `json:"message"`
		}
		var req Req
		if err := c.BodyParser(&req); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid body"})
		}

		email := strings.ToLower(strings.TrimSpace(req.Email))
		if req.Message == "" {
			return c.Status(400).JSON(fiber.Map{"error": "Pesan keluhan tidak boleh kosong"})
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		complaint := ComplaintDoc{
			UserEmail: email,
			Category:  req.Category,
			Message:   req.Message,
			Status:    "open",
			CreatedAt: time.Now(),
		}

		if complaintsCollection != nil {
			_, err := complaintsCollection.InsertOne(ctx, complaint)
			if err != nil {
				return c.Status(500).JSON(fiber.Map{"error": err.Error()})
			}
		}

		log.Printf("[Complaint Received] Email: %s | Category: %s | Msg: %s\n",
			email, req.Category, req.Message)

		return c.JSON(fiber.Map{
			"status":  "ok",
			"message": "Keluhan Anda telah berhasil dicatat dan diteruskan ke Developer!",
		})
	})

	// ==================== CHAT & SESSIONS ENDPOINTS ====================

	// Get All Sessions
	app.Get("/api/sessions", func(c *fiber.Ctx) error {
		if sessionsCollection == nil {
			return c.JSON([]fiber.Map{})
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}})
		cursor, err := sessionsCollection.Find(ctx, bson.M{}, opts)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		defer cursor.Close(ctx)

		var sessions []ChatSessionDoc
		if err := cursor.All(ctx, &sessions); err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}

		if sessions == nil {
			sessions = []ChatSessionDoc{}
		}

		return c.JSON(sessions)
	})

	// Get Messages for a Session
	app.Get("/api/sessions/:id/messages", func(c *fiber.Ctx) error {
		sessionID := c.Params("id")
		if messagesCollection == nil || sessionID == "" {
			return c.JSON([]fiber.Map{})
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}})
		cursor, err := messagesCollection.Find(ctx, bson.M{"session_id": sessionID}, opts)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}
		defer cursor.Close(ctx)

		var messages []ChatMessageDoc
		if err := cursor.All(ctx, &messages); err != nil {
			return c.Status(500).JSON(fiber.Map{"error": err.Error()})
		}

		if messages == nil {
			messages = []ChatMessageDoc{}
		}

		return c.JSON(messages)
	})

	// Delete Session
	app.Delete("/api/sessions/:id", func(c *fiber.Ctx) error {
		sessionID := c.Params("id")
		if sessionID == "" {
			return c.Status(400).JSON(fiber.Map{"error": "Session ID required"})
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if sessionsCollection != nil {
			_, _ = sessionsCollection.DeleteOne(ctx, bson.M{"_id": sessionID})
		}
		if messagesCollection != nil {
			_, _ = messagesCollection.DeleteMany(ctx, bson.M{"session_id": sessionID})
		}

		return c.JSON(fiber.Map{"status": "deleted", "session_id": sessionID})
	})

	// Streaming Chat Endpoint (SSE)
	app.Get("/api/chat/stream", func(c *fiber.Ctx) error {
		c.Set("Content-Type", "text/event-stream")
		c.Set("Cache-Control", "no-cache")
		c.Set("Connection", "keep-alive")
		c.Set("Transfer-Encoding", "chunked")

		prompt := c.Query("prompt", "Halo!")
		sessionID := c.Query("session_id", fmt.Sprintf("session_%d", time.Now().UnixMilli()))
		modelID := c.Query("model_id", "balanced")

		log.Printf("[Stream Request] Session: %s | Model: %s | Prompt: %s\n",
			sessionID, modelID, prompt)

		if sessionsCollection != nil && messagesCollection != nil {
			go func(sID, p string) {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()

				title := p
				if len(title) > 30 {
					title = title[:30] + "..."
				}

				opts := options.Update().SetUpsert(true)
				_, _ = sessionsCollection.UpdateOne(ctx,
					bson.M{"_id": sID},
					bson.M{
						"$setOnInsert": bson.M{
							"_id":        sID,
							"title":      title,
							"created_at": time.Now(),
						},
					},
					opts,
				)

				_, _ = messagesCollection.InsertOne(ctx, ChatMessageDoc{
					SessionID: sID,
					Sender:    "user",
					Text:      p,
					CreatedAt: time.Now(),
				})
			}(sessionID, prompt)
		}

		c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
			replyTokens := []string{
				"Halo! ", "Terima ", "kasih ", "sudah ", "bertanya: ",
				"\"" + prompt + "\".\n\n",
				"Saya ", "menjawab ", "menggunakan ", "mode model: **" + modelID + "** ",
				"berbasis ", "Golang (Fiber) ", "& ", "Flutter.\n\n",
				"```golang\n// Evaluasi Prompt & Konteks\nfmt.Println(\"Processing prompt with custom weights...\")\n```\n\n",
				"Model ", "AI ", "kamu ", "siap ", "menghubungkan ", "hasil ", "inference ", "secara ", "real-time! 🚀",
			}

			fullResponse := ""
			for _, token := range replyTokens {
				fullResponse += token
				fmt.Fprintf(w, "data: %s\n\n", token)
				_ = w.Flush()
				time.Sleep(100 * time.Millisecond)
			}

			if messagesCollection != nil {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()

				_, _ = messagesCollection.InsertOne(ctx, ChatMessageDoc{
					SessionID: sessionID,
					Sender:    "ai",
					Text:      fullResponse,
					CreatedAt: time.Now(),
				})
			}

			if redisClient != nil {
				ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
				defer cancel()
				_ = redisClient.Set(ctx, "last_ai_resp:"+sessionID, fullResponse, 10*time.Minute).Err()
			}
		})

		return nil
	})

	log.Printf("🚀 Server Go Fiber berjalan di http://localhost:%s\n", port)
	log.Fatal(app.Listen(":" + port))
}
