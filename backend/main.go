package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
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

type ChatSessionDoc struct {
	ID        string    `bson:"_id" json:"id"`
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

var (
	mongoClient        *mongo.Client
	sessionsCollection *mongo.Collection
	messagesCollection *mongo.Collection
	redisClient        *redis.Client
)

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
			sessionsCollection = db.Collection("sessions")
			messagesCollection = db.Collection("messages")
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

	// Streaming chat endpoint (SSE)
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

		// Simpan / update Session & User Message ke MongoDB
		if sessionsCollection != nil && messagesCollection != nil {
			go func(sID, p string) {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()

				// Upsert session
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

				// Insert user message
				_, _ = messagesCollection.InsertOne(ctx, ChatMessageDoc{
					SessionID: sID,
					Sender:    "user",
					Text:      p,
					CreatedAt: time.Now(),
				})
			}(sessionID, prompt)
		}

		c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
			// Simulasi response token dari model AI pilihan user
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

			// Simpan respon AI ke MongoDB & Redis
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
