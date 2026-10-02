# Wheelchair Control

**Repository owner:** Ishan Singla

A smart pediatric wheelchair for children with dystonia and cerebral palsy, with two control modes: a Bluetooth mobile app (Flutter) and a custom physical joystick. The chair is driven by an ESP32 running C++ firmware with built-in safety interlocks.

## Demonstration

### App Demo
<img width="1920" height="1080" alt="App demo overview" src="https://github.com/user-attachments/assets/6346e21a-d817-4a8b-9863-ede89bfa35b9" />
<video src="https://github.com/user-attachments/assets/be0c1dde-b660-423d-8b2b-dfd5394c62ef" controls muted width="480"></video>

### Final Working Video

<p>
  <a href="https://youtube.com/shorts/QyPg3e10AqY">
    <img src="https://img.youtube.com/vi/QyPg3e10AqY/hqdefault.jpg" alt="Watch the final working video" width="360" />
  </a>
</p>

<p>Click the thumbnail to watch the final working video on YouTube.</p>

### Test Runs

<video src="https://github.com/user-attachments/assets/cc91fba1-e7d6-4263-8073-336e60db099c" controls muted width="360"></video>
<video src="https://github.com/user-attachments/assets/78ad5105-e160-4110-9d6c-24346627a614" controls muted width="360"></video>

## Project at a Glance

<table>
  <tr>
    <td align="center"><img width="300" alt="Final CAD" src="https://github.com/user-attachments/assets/0db99e80-1a93-40f2-9776-df530c04096e" /><br /><b>Final CAD</b></td>
    <td align="center"><img width="300" alt="Assembled wheelchair with electronics" src="https://github.com/user-attachments/assets/ada240af-36f5-4ea3-a4de-616b91b0627f" /><br /><b>Assembled Chair</b></td>
    <td align="center"><img width="300" alt="Final Product" src="https://github.com/user-attachments/assets/d4338777-e089-47e9-9e3c-1a3b2aed450b" /><br /><b>Final Product</b></td>
  </tr>
</table>

## Key Features

- Two control modes: BLE mobile app and custom joystick
- Secure BLE pairing with a six-digit passkey and a trusted-device policy
- Indoor and outdoor driving modes with adjustable sensitivity
- Virtual joystick with bounded, sequenced movement commands
- Lock and unlock control, with biometric or device passcode confirmation for unlocking
- Emergency Stop and separate SOS assistance with call and SMS flows
- Live telemetry: connection state, movement, speed, battery, charging, faults, and diagnostics
- Watchdogs, control leases, and interlocks that stop the chair on any loss of safe control

## Technology Stack

| Layer | Technology |
| :-- | :-- |
| Mobile application | Flutter (Dart) |
| Embedded controller | ESP32 |
| Firmware | C++ |
| Wireless link | Bluetooth Low Energy (BLE), encrypted GATT |
| Motor control | PWM with ramping and direction dead time |

## Team

This project was designed and built by the following team.

| Name | Contribution |
| :-- | :-- |
| Ishan Singla | Software Design & Development, Software/Hardware Integration, Calibration |
| Anish Goel | System Design and Integration, Fabrication |
| Ayush Sihag | Mechanical Structure Design, Fabrication, Assembly |
| Shivam Dua | Mechanical Structure Design, Fabrication |
| Sachitya Agarwal | Product Design, Documentation |
| Anushka | Procurement Support, Fabrication |

## Overview

Pediatric patients with dystonia and cerebral palsy often have involuntary or limited motor control, which makes conventional wheelchair controls difficult or unsafe to use. This project provides a caregiver-first control system in which a companion operates the chair through a mobile app, alongside a joystick interface for direct operation. Safety is the central design requirement: loss of communication, stale commands, charging, and faults all move the chair to a safe, stopped, and locked state.

The project covers the complete product, from mechanical fabrication and electronics integration to embedded firmware and the caregiver mobile app.

## Fabrication Stages

<table>
  <tr>
    <td align="center"><img width="300" alt="Final CAD" src="https://github.com/user-attachments/assets/0db99e80-1a93-40f2-9776-df530c04096e" /><br /><b>Final CAD</b></td>
    <td align="center"><img width="300" alt="Metal procurement and cutting" src="https://github.com/user-attachments/assets/74aed8f8-d769-4d48-bb47-de1516bbcba2" /><br /><b>Metal Procurement and Cutting</b></td>
    <td align="center"><img width="300" alt="Welding the frame" src="https://github.com/user-attachments/assets/2bd9344e-6f1e-4acb-953d-1f3daa85447b" /><br /><b>Welding the Frame</b></td>
  </tr>
  <tr>
    <td align="center"><img width="300" alt="Primer and paint" src="https://github.com/user-attachments/assets/35beecb6-7de3-4a5a-af38-d220e36555f2" /><br /><b>Primer</b></td>
    <td align="center"><img width="300" alt="Primer and paint, second view" src="https://github.com/user-attachments/assets/be786bff-19c8-4d6d-bb42-235666fce604" /><br /><b>Paint</b></td>
    <td align="center"><img width="300" alt="Assembly and electronics integration" src="https://github.com/user-attachments/assets/ada240af-36f5-4ea3-a4de-616b91b0627f" /><br /><b>Assembly and Electronics Integration</b></td>
  </tr>
  <tr>
    <td align="center"><img width="300" alt="Cushion assembly" src="https://github.com/user-attachments/assets/6a8d5168-7302-45b2-bf91-15933fad2184" /><br /><b>Cushion Assembly</b></td>
    <td align="center"><img width="300" alt="Custom joystick assembly" src="https://github.com/user-attachments/assets/8b21d269-f7c9-49a1-bf2e-2df291b2408e" /><br /><b>Custom Joystick Assembly</b></td>
    <td align="center"><img width="300" alt="Custom joystick assembly, second view" src="https://github.com/user-attachments/assets/4bb09049-4bc8-4fe4-824b-6d011b83738a" /><br /><b>Custom Joystick Assembly (Second View)</b></td>
  </tr>
</table>

## System Architecture

| Layer | Responsibility |
| :-- | :-- |
| Mobile app | Control, Status, and Settings screens; emergency assistance; device authentication |
| BLE transport | Encrypted GATT link with framed, CRC-checked, sequenced commands and acknowledgements |
| ESP32 controller | State machine, watchdogs, motor control, trust policy, sensors, standby |

## Features

### Mobile App

- **Simple three-screen design:** Control, Status, and Settings, each with one clear purpose.
- **Virtual joystick:** drive the chair with a hold-and-move joystick. Releasing it brings the chair to a smooth stop.
- **Indoor and Outdoor modes:** precise, gentle driving indoors and stronger, balanced power outdoors, with adjustable sensitivity.
- **Secure pairing:** encrypted Bluetooth connection protected by a passkey, with a trusted-device policy so only approved caregiver phones can connect.
- **Protected unlocking:** the chair stays locked after connecting and can only be unlocked with biometric or device passcode confirmation.
- **Live status:** connection, lock state, movement, battery, charging, and fault information, shown only when fresh and never estimated.
- **Emergency Stop:** one-tap stop that latches the chair in a safe state until it is physically reset.
- **SOS assistance:** triggered from the app or the chair, it alerts the caregiver and offers a call and a prepared message with location. The caregiver always makes the final confirmation.
- **Accessible layout:** designed for small screens and enlarged text without scrolling.

### Wheelchair

- **Two control modes:** caregiver control through the app, or direct control with a custom-built joystick.
- **Custom-designed dampers and damping system:** engineered in-house to absorb shocks and vibration for a smoother, more comfortable ride.
- **Custom frame:** fabricated from welded metal, then primed and painted, with a cushioned seat.
- **Smooth motor control:** gradual acceleration and deceleration, with protection against abrupt direction changes.
- **Built-in safety interlocks:** loss of connection, stale commands, expired control, charging, or any fault automatically stops the chair and locks it.
- **Charging protection:** driving and unlocking are disabled while charging.
- **Physical buttons:** a Pair/Wake button for pairing and waking from standby, and an SOS button.
- **Auto standby:** saves power when idle, locked, and fault-free, and wakes with a button press.
- **Live telemetry:** continuously reports the chair's state to the app.

## Roadmap

- Independent hardware emergency-stop circuit.
- Joystick filtering for involuntary input.
- Motor feedback, thermal, and current sensing.
- Real BMS integration.
- Backend emergency relay for when the caregiver's phone is unavailable.

## Acknowledgements

Thank you to every member of the team for their work across design, fabrication, electronics, software, procurement, and documentation.
