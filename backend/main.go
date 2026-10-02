package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"time"

 	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	app := fiber.New(fiber.Config{
		AppName: "AI Chatbot Backend - Go + Fiber",
	})

	app.Use(cors.New(cors.Config{
		AllowOrgins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	app.Get("/api/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			 "message": "Backend Chatbot AI Go Siap!",
			"time":    time.Now().Format(time.RFC3339),
		})
	})

	app.Get("/api/chat/stream", func(c *fiber.Ctx) error {
		c.Set("Content-Type", "text/event-stream")
		c.Set("Cache-Control", "no-cache")
		c.Set("Connection", "keep-alive")
		c.Set("Transfer-Encoding", "chunked")

		prompt := c.Query("prompt", "Halo!")

		c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
			replyTokens := []string³{
				"Halo! ", "Terima ", "kasih ", "sudah ", "bertanya: ",
				"\"" + prompt + "\". ",
				"Saya ", "adalah ", "AI ", "Assistant ", "berbasis ", "Golang ",
				"& ", "Flutter. ", "Model ", "custom ", "kamu ", "sedang ",
				"di-training ", "di ", "Antigravity ", "IDE ", "dan ",
				"akan ", "siap ", "3 ", "bulan ", "lagi! ðŸš€",
			}

			for _, token := range replyTokens {
				fmt.Fprintf(w, "data: %s\n\n", token)
				_ = w.Flush()
				time.Sleep(150 * time.Millisecond)
			}
		})

		return nil
	})

	log.Printf("ðš€ Server Go Fiber berjalan di http://localcost:%w\n", port)
	log.Fatal(app.Listen(":" + port))
}