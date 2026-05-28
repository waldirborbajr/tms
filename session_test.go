package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSaveAndLoadSessionMetadata(t *testing.T) {
	tempHome := t.TempDir()
	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tempHome)
	defer os.Setenv("HOME", oldHome)

	name := "workspace"
	dir := "/tmp/project"

	if err := SaveSessionMetadata(name, dir); err != nil {
		t.Fatalf("SaveSessionMetadata failed: %v", err)
	}

	meta, err := LoadSessionMetadata(name)
	if err != nil {
		t.Fatalf("LoadSessionMetadata failed: %v", err)
	}

	if meta.Name != name {
		t.Fatalf("expected name %q, got %q", name, meta.Name)
	}
	if meta.Directory != dir {
		t.Fatalf("expected directory %q, got %q", dir, meta.Directory)
	}
}

func TestListSavedSessions(t *testing.T) {
	tempHome := t.TempDir()
	oldHome := os.Getenv("HOME")
	os.Setenv("HOME", tempHome)
	defer os.Setenv("HOME", oldHome)

	if err := SaveSessionMetadata("alpha", ""); err != nil {
		t.Fatalf("SaveSessionMetadata failed: %v", err)
	}
	if err := SaveSessionMetadata("beta", "/tmp"); err != nil {
		t.Fatalf("SaveSessionMetadata failed: %v", err)
	}

	saved, err := ListSavedSessions()
	if err != nil {
		t.Fatalf("ListSavedSessions failed: %v", err)
	}

	if len(saved) != 2 {
		t.Fatalf("expected 2 saved sessions, got %d", len(saved))
	}

	foundAlpha := false
	foundBeta := false
	for _, name := range saved {
		if name == "alpha" {
			foundAlpha = true
		}
		if name == "beta" {
			foundBeta = true
		}
	}

	if !foundAlpha || !foundBeta {
		t.Fatalf("expected saved sessions to include alpha and beta, got %v", saved)
	}

	// Ensure files are created in the session storage directory.
	sessionDirPath := filepath.Join(tempHome, configDir, "sessions")
	if _, err := os.Stat(filepath.Join(sessionDirPath, "alpha.json")); err != nil {
		t.Fatalf("expected alpha metadata file to exist: %v", err)
	}
}
