# AgrI Challenge 2024 - Research Report

**Report Date:** May 1, 2026  
**Challenge Period:** 2024  
**Organizing Institutions:** ENSA (École Nationale Supérieure Agronomique) & ENSIA (École Nationale Supérieure d'Intelligence Artificielle)  
**Location:** Algiers, Algeria

---

## 1. Executive Summary

The AgrI Challenge is a data-centric agricultural machine learning competition framework designed to address a critical gap in AI deployment: the failure of laboratory-trained models in real-world farm environments.

**Key Challenge:** Models trained on controlled laboratory datasets achieve over 99% accuracy on benchmarks, yet drop to 54% accuracy in actual farm conditions. This report documents how 12 independent teams tackled this generalization problem through collaborative data collection and innovative cross-team validation methodology.

**Core Finding:** Data diversity is the primary driver of robust AI generalization. Collaborative training across multiple teams reduced validation-test accuracy gaps by 82-84% compared to single-team training.

---

## 2. The Problem: Laboratory vs. Field Performance

### The Generalization Gap

Standard AI benchmarks fail in real-world agricultural deployment:
- **Laboratory Performance:** >99% accuracy on controlled datasets
- **Field Performance:** ~54% accuracy in actual farm environments
- **Root Cause:** Not a model problem—a **data problem**

Traditional machine learning approaches rely on controlled, uniformly-collected datasets that don't capture the natural variation of real-world deployment conditions:
- Different environmental conditions
- Varying lighting and weather patterns
- Multiple device types and camera characteristics
- Different sampling strategies and timing

### Why Standard Validation Is Insufficient

"Validation accuracy was remarkably stable (≈98%) across all evaluation folds, while test accuracy varied by over 11 percentage points, confirming that validation accuracy alone is not a reliable proxy for real-world generalization."

This fundamental insight motivated the need for a novel evaluation framework.

---

## 3. The AgrI Challenge Approach

### Shifting to Data-Centric AI

Rather than providing a fixed dataset to all teams, the AgrI Challenge employs a fundamentally different strategy:

**Each team independently collects their own field data**, generating authentic distributional diversity that mirrors real deployment conditions:
- Different collection devices and cameras
- Varied environmental contexts (climate zones, soil types, ecosystems)
- Diverse sampling strategies and methodologies
- Multiple collection periods and times of day

This approach captures real-world heterogeneity that fixed benchmarks cannot reproduce.

### The Challenge Design

- **12 Independent Teams:** Each with their own data collection methodology
- **Field-Based Data:** Real agricultural environments across Algiers region
- **Collaborative Framework:** Teams share data for model evaluation
- **Transparent Evaluation:** Cross-team validation protocols ensure fairness

---

## 4. The Dataset

### Scale & Composition

- **Total Raw Images Collected:** 50,673
- **Curated Benchmark Images:** 47,367 (high-quality subset)
- **Tree Species:** 6 classes (all commercially or ecologically important in North Africa)

### Tree Species Classification

1. **Carob** (*Ceratonia siliqua*)
   - Mediterranean species, important for livestock feed and human consumption
   
2. **Oak** (*Quercus* spp.)
   - Dominant tree species in Mediterranean forests
   
3. **Peruvian Pepper** (*Schinus molle*)
   - Ornamental and shade tree species
   
4. **Ash** (*Fraxinus* spp.)
   - Important for timber and biomass
   
5. **Pistachio** (*Pistacia vera*)
   - High-value crop with significant commercial importance
   
6. **Tipuana** (*Tipuana tipu*)
   - Shade tree and ornamental species

### Data Distribution by Team

| Team | Carob | Oak | Pepper | Ash | Pistachio | Tipuana | Total |
|------|-------|-----|--------|-----|-----------|---------|-------|
| AI-4o | 960 | 1,625 | 1,221 | 934 | 1,111 | 1,493 | 7,344 |
| AiGro | 686 | 604 | 595 | 572 | 541 | 635 | 3,633 |
| CACTUS | 400 | 597 | 694 | 803 | 755 | 552 | 3,801 |
| CHAJARA | 610 | 549 | 428 | 308 | 262 | 383 | 2,540 |
| GreenAI | 675 | 705 | 609 | 559 | 722 | 515 | 3,785 |
| PLT | 1,089 | 1,131 | 1,000 | 1,297 | 973 | 1,066 | 6,556 |
| RUSTICUS | 565 | 625 | 505 | 500 | 555 | 696 | 3,446 |
| SMART AGRICULTURES | 638 | 923 | 1,694 | 1,214 | 1,080 | 772 | 6,321 |
| Scorpions | 422 | 450 | 407 | 456 | 620 | 440 | 2,795 |
| Condimenteum | 1,048 | 1,000 | 655 | 1,074 | 606 | 1,121 | 5,504 |
| The Neural Ninjas | 234 | 262 | 256 | 236 | 293 | 361 | 1,642 |
| Organization team | 552 | 657 | 727 | 392 | 368 | 610 | 3,306 |
| **TOTAL** | **7,879** | **9,128** | **8,791** | **8,345** | **7,886** | **8,644** | **50,673** |

### Key Observations

- **Uneven Distribution:** Teams contributed varying numbers of images (1,642 to 7,344)
- **Species Coverage:** Each team collected data for all 6 species, but with different emphasis
- **Natural Variation:** Distribution reflects real-world differences in collection efforts, environmental factors, and team capabilities
- **Diversity Benefit:** Uneven distribution enhances the dataset's ability to capture real-world heterogeneity

---

## 5. Cross-Team Validation (CTV) Framework

### Novel Evaluation Methodology

The AgrI Challenge introduces a new paradigm for evaluating model generalization: treating each team's independently-collected dataset as a distinct domain.

Unlike traditional cross-validation that randomly splits data, CTV preserves domain boundaries created by different collection contexts, providing realistic assessment of how models generalize to unseen domains.

### Protocol A: TOTO (Train-On-One-Team-Only)

**Objective:** Measure single-source generalization capability

**Setup:**
- **Training:** 70% of a single team's data
- **Validation:** 30% of same team's data
- **Testing:** Each of the other 11 teams' datasets independently

**Key Finding:** Single-team training reveals large validation-test accuracy gaps:
- **DenseNet121:** 16.20% gap (97.40% val → 81.19% test)
- **Swin Transformer:** 11.37% gap (98.59% val → 87.21% test)

This gap indicates that the team's validation set is not representative of other teams' domains—a critical problem for real-world deployment.

### Protocol B: LOTO (Leave-One-Team-Out)

**Objective:** Measure collaborative, multi-source generalization

**Setup:**
- **Training:** 70% of combined data from 11 teams (all except one)
- **Validation:** 30% from training set
- **Testing:** Held-out team's entire dataset

**Key Finding:** Collaborative training dramatically reduces the validation-test gap:
- **DenseNet121:** Gap reduces to 2.82% (+14.12 percentage points improvement)
- **Swin Transformer:** Gap reduces to 1.78% (+9.83 percentage points improvement)

### Critical Insight

The nearly 12x reduction in validation-test gap under LOTO reveals that data diversity is the dominant factor in generalization. When models are trained on diverse data sources representing different collection methodologies and environments, they generalize far better to unseen domains.

---

## 6. Baseline Results

### Evaluated Architectures

Two distinct model families were evaluated to test generalization across different architectural paradigms:

#### 1. DenseNet121 (Convolutional Neural Network)

**Architecture Characteristics:**
- Dense connections between layers for efficient feature reuse
- 8 million parameters
- Pretrained on ImageNet-1K

**TOTO Protocol Results (Single-Team Training):**
- Validation Accuracy: 97.40%
- Test Accuracy: 81.19%
- Validation-Test Gap: 16.20 percentage points

**LOTO Protocol Results (Multi-Team Training):**
- Single-Team Score: 81.19%
- Multi-Team Score: 95.31%
- Performance Improvement: +14.12 percentage points
- New Validation-Test Gap: 2.82 percentage points
- Gap Reduction: 82% improvement
- Performance Variance Reduction: 40%

**Interpretation:** DenseNet's efficiency is limited by single-domain training but thrives with diverse data, achieving 95% accuracy when trained collaboratively.

#### 2. Swin Transformer (Vision Transformer)

**Architecture Characteristics:**
- Window-based self-attention with shifted windowing
- 28 million parameters (3.5x larger than DenseNet121)
- Pretrained on ImageNet-1K

**TOTO Protocol Results (Single-Team Training):**
- Validation Accuracy: 98.59%
- Test Accuracy: 87.21%
- Validation-Test Gap: 11.37 percentage points

**LOTO Protocol Results (Multi-Team Training):**
- Single-Team Score: 87.21%
- Multi-Team Score: 97.04%
- Performance Improvement: +9.83 percentage points
- New Validation-Test Gap: 1.78 percentage points
- Gap Reduction: 84% improvement
- Performance Variance Reduction: 54%

**Interpretation:** Transformers benefit even more from collaborative training (84% gap reduction vs. 82% for CNNs), with lower variance across folds. Despite larger model size, training on diverse data is more effective than architectural complexity.

### Training Configuration

Both models were trained under identical conditions for fair comparison:
- **Optimizer:** AdamW with weight decay
- **Learning Rate:** 1e-4
- **Weight Decay:** 1e-4
- **Learning Rate Schedule:** Cosine annealing
- **Batch Size:** 32
- **Training Duration:** 20 epochs
- **Input Resolution:** 224×224 pixels
- **Hardware:** NVIDIA H100 NVL GPU

### Performance Summary

| Metric | DenseNet121 | Swin Transformer |
|--------|-------------|------------------|
| **Model Parameters** | 8M | 28M |
| **TOTO Val Accuracy** | 97.40% | 98.59% |
| **TOTO Test Accuracy** | 81.19% | 87.21% |
| **TOTO Gap** | 16.20pp | 11.37pp |
| **LOTO Accuracy** | 95.31% | 97.04% |
| **LOTO Gap** | 2.82pp | 1.78pp |
| **Gap Reduction** | 82% | 84% |
| **Absolute Improvement** | +14.12pp | +9.83pp |

### Key Takeaways

1. **Data Trumps Model Size:** An 8M-parameter CNN trained on diverse data outperforms single-team training of a 28M-parameter Transformer
2. **Generalization Priority:** The 82-84% gap reduction demonstrates that generalization is primarily a data problem, not an architecture problem
3. **Reliable Validation:** LOTO protocol provides ~2% validation-test gap, indicating good alignment between validation and true generalization
4. **Consistency:** Both architectures show the same pattern (large gap → small gap), validating the methodology

---

## 7. Research Contributions

### 1. Cross-Team Validation (CTV) Framework

A novel evaluation paradigm that treats each team's independently-collected dataset as a distinct domain, enabling realistic assessment of model generalization across genuinely different data sources.

**Innovation:** Unlike random cross-validation, CTV preserves real-world domain boundaries, providing more ecologically valid evaluation.

### 2. Evidence for Data-Centric AI

Quantitative demonstration that data diversity is the primary driver of robust generalization:
- Single-source training produces 11-16% validation-test gaps
- Multi-source training reduces this to 1.8-2.8%
- Gap reduction of 82-84% across architectures

### 3. Benchmark Dataset

47,367 high-quality agricultural tree species classification images collected by 12 teams using diverse methodologies, providing authentic real-world variation for future research.

### 4. Methodological Transparency

Complete documentation of:
- Data collection protocols
- Team contributions
- Training procedures
- Evaluation metrics
- Open-source code and reproducible results

---

## 8. Organizing Institutions

### ENSA (École Nationale Supérieure Agronomique)
**Location:** El Harrach, Algiers, Algeria  
**Founded:** 1905  
**Role in Challenge:** Field data collection host, Data Collection Phase

A long-established agronomic institution with:
- Experimental and teaching facilities representing diverse agro-ecosystems
- Well-maintained plant collections
- Access to representative agricultural environments
- Infrastructure for coordinating 12 independent data collection teams

**Website:** https://www.ensa.dz

### ENSIA (École Nationale Supérieure d'Intelligence Artificielle)
**Location:** Algiers, Algeria  
**Role in Challenge:** Model development host, Model Development Phase

A national center of excellence dedicated to:
- AI and machine learning education
- Applied research in artificial intelligence
- AI expertise and mentorship for participating teams
- Model development coordination and evaluation

**Website:** https://www.ensia.edu.dz

### Collaboration

The partnership between ENSA and ENSIA created a unique opportunity to combine:
- **Agricultural domain expertise** (ENSA)
- **AI/ML technical expertise** (ENSIA)

This collaboration enabled teams to work in realistic agricultural settings while receiving guidance on machine learning methodology and evaluation.

---

## 9. Participating Teams (12 Total)

The diversity of teams contributed to dataset heterogeneity:

1. **AI-4o** (7,344 images)
2. **AiGro** (3,633 images)
3. **CACTUS** (3,801 images)
4. **CHAJARA** (2,540 images)
5. **GreenAI** (3,785 images)
6. **PLT** (6,556 images)
7. **RUSTICUS** (3,446 images)
8. **SMART AGRICULTURES** (6,321 images)
9. **Scorpions** (2,795 images)
10. **Condimenteum** (5,504 images)
11. **The Neural Ninjas** (1,642 images)
12. **Organization team** (3,306 images)

Each team brought unique perspectives, equipment, and collection strategies, naturally creating the dataset diversity essential for the research.

---

## 10. Academic Publication

### Citation

**APA Format:**
Brahimi, M., Laabassi, K., Hadj Ameur, M. S., Boutorh, A., Siab-Farsi, B., Khouani, A., Zouak, O. F., Bouziane, S. E., Lakhdari, K., & Benghanem, A. N. (2026). AgrI Challenge: Cross-Team Insights from a Data-Centric AI Competition in Agricultural Vision. arXiv preprint. https://arxiv.org/abs/2603.07356

### Publication Details

- **Title:** AgrI Challenge: Cross-Team Insights from a Data-Centric AI Competition in Agricultural Vision
- **Authors:** 10 researchers from ENSA and ENSIA
- **Corresponding Author:** Dr. Mohammed Brahimi, ENSIA, Algiers, Algeria
- **Contact Email:** mohamed.brahimi@ensia.edu.dz
- **Year:** 2026
- **arXiv ID:** 2603.07356
- **Full Paper URL:** https://arxiv.org/abs/2603.07356

### Paper Contents

The published paper includes:
- Detailed methodology descriptions
- Complete results analysis
- Statistical significance testing
- Supplementary materials and extended data
- Code availability and reproducibility information

---

## 11. Open-Source Resources

### GitHub Repository

**URL:** https://github.com/Agri-Challenge/agri-challenge-scripts-2024

**Contents:**
- Data preparation and curation scripts
- Cross-Team Validation (CTV) framework implementation
- Baseline model training code (DenseNet121, Swin Transformer)
- Evaluation metrics and analysis scripts
- Documentation for dataset access and usage

### Reproducibility

The open-source repository ensures:
- **Transparency:** All methods are documented and reproducible
- **Accessibility:** Code is publicly available for verification and extension
- **Extensibility:** Researchers can build on the framework
- **Benchmark:** Establishes standardized evaluation procedures

---

## 12. Key Findings & Implications

### Primary Findings

#### 1. Data Diversity Drives Generalization
**Finding:** Moving from single-team to multi-team training reduces validation-test accuracy gap by 82-84%.

**Implication:** For real-world agricultural AI deployment, collecting data from multiple sources and environments is more important than model architecture complexity.

#### 2. Validation Accuracy Is Not Reliable
**Finding:** Models achieved 97-99% validation accuracy under single-team training but only 81-87% field accuracy.

**Implication:** Standard validation metrics are insufficient for assessing real-world generalization. Domain diversity must be included in evaluation protocols.

#### 3. Cross-Team Validation Provides Better Assessment
**Finding:** LOTO protocol validation-test gaps (1.8-2.8%) align well with real-world performance expectations.

**Implication:** The CTV methodology provides a more realistic estimate of model generalization than standard cross-validation.

#### 4. Architecture Matters Less Than Expected
**Finding:** An 8M-parameter CNN trained on diverse data outperforms a 28M-parameter Transformer trained on single-team data.

**Implication:** For agricultural applications, focus should be on data collection and diversity before investing in larger models.

### Practical Implications for Agriculture

1. **For Farmers & Extension Services:**
   - AI systems are most reliable when trained on diverse farm conditions
   - Single-farm training will likely fail on other farms
   - Collaborative data sharing improves accuracy for all participants

2. **For Researchers:**
   - Agricultural computer vision benchmarks must capture real-world diversity
   - Single-source datasets are insufficient for deployment
   - Cross-site validation should be standard practice

3. **For Industry:**
   - Agricultural AI products should be trained on diverse data sources
   - Generalization testing across different environments is critical
   - Collaborative approaches improve product quality

---

## 13. Limitations & Future Directions

### Current Limitations

1. **Geographic Scope:** Data collected only in Algiers region; generalization to other climates unknown
2. **Species Coverage:** Only 6 tree species; many other agricultural crops remain unexplored
3. **Image Type:** Static image classification; temporal dynamics not captured
4. **Model Scale:** Limited to two baseline architectures; foundation models not evaluated
5. **Small Team 11:** "The Neural Ninjas" contributed only 1,642 images, potentially limited data diversity

### Future Research Directions

1. **Temporal Dynamics:** Multi-temporal monitoring to capture seasonal changes
2. **Geographic Expansion:** Collaborate with international teams to assess cross-continental generalization
3. **Task Expansion:** Disease detection, pest management, yield prediction
4. **Foundation Models:** Evaluate large pre-trained vision models (CLIP, SAM, etc.)
5. **Real-Time Deployment:** Edge device implementation and latency assessment
6. **Multi-Modal Integration:** Combine images with sensor data and environmental variables
7. **Explainability:** Investigate which environmental factors drive performance variations

---

## 14. Conclusion

The AgrI Challenge demonstrates that **data diversity is the fundamental requirement for robust agricultural AI systems**. The 82-84% reduction in validation-test accuracy gaps when training on collaborative multi-team data provides quantitative evidence for this principle.

### Key Takeaways

✓ **Data-Centric Approach Works:** Collaborative data collection from diverse sources significantly improves generalization  
✓ **Validation Alone Insufficient:** Standard validation metrics cannot predict field performance; domain diversity is required  
✓ **CTV Framework Effective:** Cross-team validation provides realistic assessment of real-world generalization  
✓ **Generalization Over Architecture:** Data diversity matters more than model complexity  
✓ **Open Science Enables Progress:** Transparent methodology and code promote reproducibility and extension  

### Vision for Agricultural AI

The AgrI Challenge envisions a future where:
- Agricultural AI systems are collaboratively developed across multiple stakeholders
- Data diversity is prioritized in benchmarks and evaluation
- Generalization to real-world conditions is the success metric
- Research findings are openly shared and reproducible
- Technology improves food security through robust, reliable AI

---

## 15. Contact & Access

### For Questions or Inquiries

**Primary Contact:**
- Dr. Mohammed Brahimi (ENSIA)
- Email: mohamed.brahimi@ensia.edu.dz
- Affiliation: École Nationale Supérieure d'Intelligence Artificielle

**Institutional Contacts:**
- ENSA: https://www.ensa.dz
- ENSIA: https://www.ensia.edu.dz

### Dataset Access

For information regarding:
- Dataset access and usage agreements
- Collaboration opportunities
- Research partnerships
- Extension of the AgrI Challenge

Please contact the corresponding author via email.

---

## Appendix: Research Team

**Authors:**
- M. Brahimi
- K. Laabassi
- M. S. Hadj Ameur
- A. Boutorh
- B. Siab-Farsi
- A. Khouani
- O. F. Zouak
- S. E. Bouziane
- K. Lakhdari
- A. N. Benghanem

**Affiliations:** ENSA and ENSIA, Algiers, Algeria

**Year:** 2026

---

**End of Report**
