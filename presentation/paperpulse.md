---
marp: true
theme: default
paginate: true
header: "PaperPulse - Intelligent Document Processing"
footer: "Buttinger, Gudic"
style: |
  section {
    font-size: 1.5em;
  }
  h1 {
    color: #0072C6;
  }
---

# PaperPulse
## Serverless Document Processing Platform

---

# Overview

- Automatic document analysis and metadata extraction
- Built entirely on Azure serverless architecture
- Focus on scalability and cost efficiency
- Infrastructure as Code (IaC) with Azure Bicep

---

# Architecture
![bg right:65% 90%](architecture.png)

---

# Key Cloud Features

- **Serverless Architecture**
  - Azure Functions
  - Pay-per-use model
  - Auto-scaling

- **Managed Services**
  - Cosmos DB for NoSQL storage
  - Form Recognizer for AI processing
  - Key Vault for secrets

---

# Cost Analysis (Monthly)

- Azure Functions: $0-50
- Cosmos DB: $25-100
- Blob Storage: $0.02/GB
- Form Recognizer: Pay-per-document
- API Management: $0 (consumption)
- Static Web App: Free tier

*40-60% savings vs on-premises*

---

# Scalability & Performance

- **Auto-scaling** at every layer
  - Functions scale to zero
  - Cosmos DB auto-scales
  - Blob storage virtually unlimited

- **High Availability**
  - Multi-region deployment options
  - Built-in redundancy
  - Automatic failover

---

# Security Implementation

- Azure Key Vault integration
- Managed Identities
- RBAC for service access
- HTTPS-only communication
- API Management security

![bg right:65% 90%](keyvault.png)

---

# Live Demo Time

---

# Key Learnings

- Serverless isn't always simpler
- Scripting saves time
- Azure documentation can be misleading
- Cost optimization requires planning
- Infrastructure as Code is essential
- https://github.com/Azure/Azure-Functions/issues/2248

---

# Thank You!

Questions?

[GitHub Repository](https://github.com/xaverb/paperpulse)