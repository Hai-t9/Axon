---
sidebar_position: 1
title: System Architecture Overview
---

# System Architecture Overview

The system architecture adopted in Axon is a layered architecture, each concern (ie, a feature or a component) is intra-separated and connected with receivers and transmitters, and inter-separated into 3 sub-components of :

1. Controllers | react to a particular event in the frontend and communicate with a route.
2. Services | receive the message from the route in question to execute the 'what'.
3. Repositories | the data layer, listens to its services and is the part responsible for retrieving and modifying records in the database.
