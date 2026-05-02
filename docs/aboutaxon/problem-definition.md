---
sidebar_position: 1
title: Problem Definition
---

# Problem Definition

Nowadays, many entities and organizations struggle with hosting and delivering end-to-end workflows to collect data and evaluate AI models from multiple teams and streams, This. in turn, would create a lot of isolation, setbacks, format issues and standards mismatching.



## About Agrichallenge

Agrichallenge is an event that was hosted in 2025 and 2024 by ENSIA and ENSA, sponsored by Mobilis and incubated by the V2V incubator, its purpose is to generalise computer vision classifiers that label 6 species of plants, the new strategy being used is cross team validation with the protocols of LOTO (Leave One Team Out) and TOTO (Train On One Team Only)

## Main Pain Points

1. Missing data and metadata (around 10k images were dropped for missing the device column)
2. Different file formats and image dimensions
3. Bottleneck on the discord bot that was used to evaluate the different classifier models
4. Irritating organisation and administration across the competition
5. Tedious and unstandardised storage dumps (images were stored in google drive)


## Solution Overview

Axon is the proposed solution for the problems presented above.

Axon is a cross platform software used to facilitate the likes of the endeavours of Agrichallenge, the first prototype will be directed towards Agrichallenge 2026.

Axon allows organisers to host data collection and model evaluation competitions and customising the configurations to their specifications.

Participants would then join the competition and use the mobile version to take images and transfer them to a database without directly communicating with the low level system components.

After each team is done collecting images, they would go on with training and submitting a computer vision classifier, then to be evaluated with TOTO or LOTO protocols by utilizing all the teams data and ranking the best teams in terms of model accuracy.