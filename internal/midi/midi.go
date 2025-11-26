package midi

import (
	"fmt"
	"log"
	"time"

	"gitlab.com/gomidi/midi/v2"
	"gitlab.com/gomidi/midi/v2/drivers"
	_ "gitlab.com/gomidi/midi/v2/drivers/rtmididrv" // autoregisters driver
)

type Client struct {
	out     drivers.Out
	channel uint8
}

func New(portName string, channel uint8) (*Client, error) {
	// Get the default MIDI driver
	drv := drivers.Get()
	if drv == nil {
		return nil, fmt.Errorf("no MIDI driver available")
	}

	// Try to find existing port or create new virtual port
	outs, err := drv.Outs()
	if err != nil {
		return nil, fmt.Errorf("failed to get MIDI outputs: %w", err)
	}

	var out drivers.Out
	for _, o := range outs {
		if o.String() == portName {
			out = o
			break
		}
	}

	// If port doesn't exist, create virtual port (platform dependent)
	if out == nil {
		log.Printf("Creating virtual MIDI port: %s", portName)
		// Note: Virtual port creation is platform-specific
		// On macOS, rtmididrv automatically creates virtual ports
		// We'll use the first available output or create one
		if len(outs) > 0 {
			out = outs[0]
			log.Printf("Using MIDI output: %s", out.String())
		} else {
			return nil, fmt.Errorf("no MIDI outputs available and cannot create virtual port")
		}
	}

	// Open the MIDI output
	if err := out.Open(); err != nil {
		return nil, fmt.Errorf("failed to open MIDI output: %w", err)
	}

	log.Printf("MIDI client initialized on channel %d", channel)

	return &Client{
		out:     out,
		channel: channel,
	}, nil
}

func (c *Client) SendNote(note uint8, velocity uint8, duration time.Duration) error {
	send, err := midi.SendTo(c.out)
	if err != nil {
		return fmt.Errorf("failed to create MIDI sender: %w", err)
	}

	// Send Note On
	if err := send(midi.NoteOn(c.channel, note, velocity)); err != nil {
		return fmt.Errorf("failed to send note on: %w", err)
	}

	log.Printf("MIDI Note On: channel=%d note=%d velocity=%d", c.channel, note, velocity)

	// Wait for duration, then send Note Off
	go func() {
		time.Sleep(duration)
		if err := send(midi.NoteOff(c.channel, note)); err != nil {
			log.Printf("Failed to send note off: %v", err)
			return
		}
		log.Printf("MIDI Note Off: channel=%d note=%d", c.channel, note)
	}()

	return nil
}

func (c *Client) Close() error {
	if c.out != nil {
		return c.out.Close()
	}
	return nil
}
