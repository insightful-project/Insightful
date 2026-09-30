# Redaction Contract — WhatsApp Flow Payload

**Source**: `dev/ins1ght/products/ins1ght-platform/devops/n8n/mock_flow_payload.json`  
**Purpose**: Define which fields leave the Insightful network when calling Jev

---

## Classification

| Field | Type | Sensitivity | Action |
|-------|------|-------------|--------|
| `id_number` | SA ID (13 digits) | **CRITICAL** | `hasIdNumber: true` |
| `home_address` | Full residential | **CRITICAL** | `hasHomeAddress: true` |
| `bank_account_number` | 11 digits | **CRITICAL** | `hasBankAccount: true` |
| `cell_phone` | Mobile number | **HIGH** | `hasCellPhone: true` |
| `email` | Email address | **HIGH** | `hasEmail: true` |
| `salary_gross` | Income | **HIGH** | `salaryBand: "32k"` |
| `kin_full_name` | Next of kin | **HIGH** | `hasKin: true` |
| `employer_name` | Employer | **MEDIUM** | `hasEmployer: true` |
| `work_telephone` | Work phone | **MEDIUM** | `hasWorkPhone: true` |
| All other fields | Various | **LOW** | Pass through |

---

## Redaction Rules

1. **Never send raw values** for CRITICAL/HIGH fields
2. **Send boolean presence flags** instead: `hasIdNumber`, `hasHomeAddress`, etc.
3. **Bucket numeric values** into bands: `salaryBand: "32k"` not `32000`
4. **Redact PII in free text** before sending (regex for ID numbers, accounts, emails)
5. **Max state size**: 2000 tokens (Jev context is 32k, but cost scales)

---

## Example Transformed State

```json
{
  "objective": "Is this loan application safe to process?",
  "state": {
    "fieldClasses": {
      "hasIdNumber": true,
      "hasHomeAddress": true,
      "hasBankAccount": true,
      "hasCellPhone": true,
      "hasEmail": true,
      "salaryBand": "32k",
      "hasKin": true,
      "hasEmployer": true,
      "hasWorkPhone": true
    },
    "text": "Application received from Thabo Nkosi for personal loan..."
  },
  "questions": {
    "safe_to_share": { "type": "noul", "instructions": "Does this contain PII that should not leave?", "true": "PII present", "false": "No PII" },
    "doc_complete": { "type": "noul", "instructions": "Are all required fields present?", "true": "Complete", "false": "Incomplete" },
    "risk": { "type": "score", "instructions": "Overall risk level", "criteria": ["Low", "Medium", "High"] }
  },
  "thresholds": { "act": 0.9, "reroute": 0.7 }
}
```

---

## Enforcement

- **n8n layer**: Apply redaction in a `Code` node before the Jev HTTP Request node
- **Jev service**: Enforces 2000 token cap on `state` (returns 413 if exceeded)
- **Audit**: Log `fieldClasses` keys + decision verdict (never raw values)

---

## Jev Question Design for This Payload

| Question ID | Type | Purpose |
|-------------|------|---------|
| `safe_to_share` | `noul` | Any PII that must not leave? |
| `pii_present` | `choice` | What class: `id` / `financial` / `contact` / `none` |
| `doc_complete` | `noul` | All required fields present? |
| `risk` | `score` | Overall risk: Low/Medium/High |

Threshold policy: `act` ≥ 0.9 → auto-approve; 0.7–0.9 → reroute to human; < 0.7 → reject.