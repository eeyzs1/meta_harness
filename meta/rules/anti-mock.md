# Anti-Mock Protocol (ZERO TOLERANCE)

**NEVER simulate, mock, stub, or fake an external dependency when the user requests real integration.**

When a user says "integrate AI", "use LLM", "connect to API", or ANY external service:

1. **STOP and CONFIRM**: "I understand you want REAL [service] integration. I will use the actual [service] API/SDK. Is that correct?"
2. **NEVER** return hardcoded responses pretending to be from the service
3. **NEVER** create `Mock*`, `Fake*`, `Stub*`, `Dummy*` classes unless explicitly for testing
4. **NEVER** use phrases like "simulated response", "mock response", "placeholder data" in production code
5. **ALWAYS** use real API keys, real endpoints, real SDKs
6. **If you cannot access the real service**: STOP and state clearly what's missing.

## Self-Check
- [ ] Am I returning invented data instead of calling a real API?
- [ ] Am I using `mock`/`fake`/`stub`/`dummy`/`simulated` in names or comments?
- [ ] Did the user ask for real integration and I gave simulated output?
- **If ANY is YES → STOP. Delete the mock. Implement the real thing or explain why you can't.**