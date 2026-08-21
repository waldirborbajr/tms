package main

import (
	"sync"
	"time"
)

// Cache simples para armazenar listas de sessões
type SessionCache struct {
	data      []string
	expiresAt time.Time
	mu        sync.RWMutex
	ttl       time.Duration
}

// NewSessionCache cria um novo cache com TTL padrão de 2 segundos
func NewSessionCache(ttl ...time.Duration) *SessionCache {
	duration := 2 * time.Second
	if len(ttl) > 0 && ttl[0] > 0 {
		duration = ttl[0]
	}
	return &SessionCache{
		ttl: duration,
	}
}

// Get retorna os dados do cache se válido
func (c *SessionCache) Get() ([]string, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.data == nil || time.Now().After(c.expiresAt) {
		return nil, false
	}
	return c.data, true
}

// Set armazena dados no cache
func (c *SessionCache) Set(data []string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = data
	c.expiresAt = time.Now().Add(c.ttl)
}

// Invalidate invalida o cache
func (c *SessionCache) Invalidate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = nil
	c.expiresAt = time.Time{}
}

// Clear limpa completamente o cache
func (c *SessionCache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = nil
	c.expiresAt = time.Time{}
}

// IsValid verifica se o cache ainda é válido
func (c *SessionCache) IsValid() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.data != nil && time.Now().Before(c.expiresAt)
}
