#!/usr/bin/env node
/**
 * QuadTrack Ping Simulator
 *
 * Generates simulated location pings and writes them to the Firestore
 * quadtrack_pings collection via REST API. Useful for testing the
 * QuadTrack tracking UI without physical hardware.
 *
 * Usage:
 *   node quadtrack-ping-simulator.js --deviceId <id> [options]
 *
 * Options:
 *   --deviceId      Required. The QuadTrack device document ID
 *   --lat           Starting latitude (default: 32.2226 — Tucson, AZ)
 *   --lng           Starting longitude (default: -110.9747)
 *   --interval      Seconds between pings (default: 10)
 *   --count         Number of pings to send (default: 50, 0 = unlimited)
 *   --pattern       Movement pattern: walk, drive, wander, stationary (default: walk)
 *   --battery       Starting battery level 0-100 (default: 85)
 *   --drain         Battery drain per ping (default: 0.5)
 *   --charging      Charging state: on_battery, charging_qi, charging_reverse, charging_pogo (default: on_battery)
 *   --source        Location source: gps, wifi, cell (default: gps)
 *   --emergency     Simulate emergency mode (rapid pings, erratic movement)
 *   --project       Firebase project ID (default: ssa-bug-dashboard)
 *   --dry-run       Print pings to console without sending to Firestore
 */

const https = require('https');

// --- Parse CLI args ---
const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg.startsWith('--')) {
    const key = arg.slice(2);
    const next = process.argv[i + 1];
    if (next && !next.startsWith('--')) {
      args[key] = next;
      i++;
    } else {
      args[key] = true;
    }
  }
}

if (!args.deviceId) {
  console.error('Error: --deviceId is required');
  console.error('Usage: node quadtrack-ping-simulator.js --deviceId <id> [options]');
  process.exit(1);
}

const config = {
  deviceId: args.deviceId,
  lat: parseFloat(args.lat || '32.2226'),
  lng: parseFloat(args.lng || '-110.9747'),
  interval: parseInt(args.interval || '10') * 1000,
  count: parseInt(args.count || '50'),
  pattern: args.pattern || 'walk',
  battery: parseFloat(args.battery || '85'),
  drain: parseFloat(args.drain || '0.5'),
  charging: args.charging || 'on_battery',
  source: args.source || 'gps',
  emergency: !!args.emergency,
  project: args.project || 'ssa-bug-dashboard',
  dryRun: !!args['dry-run'],
};

if (config.emergency) {
  config.interval = 3000; // 3s pings in emergency
}

// --- Movement patterns ---
function getMovementDelta(pattern, step) {
  const jitter = () => (Math.random() - 0.5) * 0.00005;

  switch (pattern) {
    case 'walk':
      // ~3mph walking speed, roughly north-east
      return {
        lat: 0.00003 + jitter(),
        lng: 0.00002 + jitter(),
      };
    case 'drive':
      // ~30mph driving speed
      return {
        lat: 0.0003 + (Math.random() - 0.5) * 0.0001,
        lng: 0.0002 + (Math.random() - 0.5) * 0.0001,
      };
    case 'wander':
      // Random direction each step
      const angle = Math.random() * 2 * Math.PI;
      const dist = 0.00005 + Math.random() * 0.00005;
      return {
        lat: Math.cos(angle) * dist,
        lng: Math.sin(angle) * dist,
      };
    case 'stationary':
      // GPS drift only
      return {
        lat: (Math.random() - 0.5) * 0.00001,
        lng: (Math.random() - 0.5) * 0.00001,
      };
    default:
      return { lat: 0, lng: 0 };
  }
}

function getAccuracy(source, pattern) {
  const base = source === 'gps' ? 5 : source === 'wifi' ? 30 : 500;
  return base + Math.random() * base * 0.5;
}

// --- Firestore REST API ---
function writePingToFirestore(ping) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      fields: {
        deviceId: { stringValue: ping.deviceId },
        location: {
          geoPointValue: {
            latitude: ping.latitude,
            longitude: ping.longitude,
          },
        },
        accuracy: { doubleValue: ping.accuracy },
        altitude: { doubleValue: ping.altitude },
        batteryLevel: { integerValue: String(Math.round(ping.batteryLevel)) },
        phoneBatteryLevel: { integerValue: String(Math.round(ping.phoneBatteryLevel)) },
        chargingState: { stringValue: ping.chargingState },
        source: { stringValue: ping.source },
        timestamp: { timestampValue: ping.timestamp },
      },
    });

    const options = {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${config.project}/databases/(default)/documents/quadtrack_pings`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`Firestore error ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// --- Main loop ---
async function run() {
  let lat = config.lat;
  let lng = config.lng;
  let battery = config.battery;
  let sent = 0;

  console.log(`\n🛰️  QuadTrack Ping Simulator`);
  console.log(`   Device: ${config.deviceId}`);
  console.log(`   Start:  ${lat.toFixed(6)}, ${lng.toFixed(6)}`);
  console.log(`   Pattern: ${config.pattern}${config.emergency ? ' (EMERGENCY)' : ''}`);
  console.log(`   Interval: ${config.interval / 1000}s | Count: ${config.count || '∞'}`);
  console.log(`   Battery: ${battery}% (drain: ${config.drain}%/ping)`);
  console.log(`   Mode: ${config.dryRun ? 'DRY RUN' : 'LIVE → Firestore'}\n`);

  const sendPing = async () => {
    const delta = getMovementDelta(config.pattern, sent);
    lat += delta.lat;
    lng += delta.lng;
    battery = Math.max(0, battery - config.drain);

    const ping = {
      deviceId: config.deviceId,
      latitude: lat,
      longitude: lng,
      accuracy: getAccuracy(config.source, config.pattern),
      altitude: 728 + (Math.random() - 0.5) * 5, // ~Tucson elevation
      batteryLevel: battery,
      phoneBatteryLevel: 60 + Math.random() * 30,
      chargingState: config.charging,
      source: config.source,
      timestamp: new Date().toISOString(),
    };

    sent++;
    const prefix = `[${sent}${config.count ? '/' + config.count : ''}]`;

    if (config.dryRun) {
      console.log(`${prefix} 📍 ${lat.toFixed(6)}, ${lng.toFixed(6)} | 🔋 ${Math.round(battery)}% | ${config.source}`);
    } else {
      try {
        await writePingToFirestore(ping);
        console.log(`${prefix} ✅ ${lat.toFixed(6)}, ${lng.toFixed(6)} | 🔋 ${Math.round(battery)}%`);
      } catch (err) {
        console.error(`${prefix} ❌ ${err.message}`);
      }
    }

    if (battery <= 0) {
      console.log('\n🪫 Battery depleted. Stopping.');
      return;
    }

    if (config.count && sent >= config.count) {
      console.log(`\n✅ Sent ${sent} pings. Done.`);
      return;
    }

    setTimeout(sendPing, config.interval);
  };

  await sendPing();
}

run().catch(console.error);
