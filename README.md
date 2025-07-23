# Spex

**Write a 5-line spec. Get a complete data pipeline.**

Spex uses AI to generate production-ready PySpark/Python/SQL pipelines from simple specifications. No more boilerplate. No more setup hassle. Just describe what you want.

## Install (30 seconds)

```bash
git clone <this-repo>
cd spex
swift build -c release
sudo cp .build/release/spex /usr/local/bin/
```

## Use (2 minutes)

```bash
spex
```

That's it. Follow the prompts, answer a few questions, and watch your pipeline appear.

## Example

Say you want to analyze app events:

1. Run `spex`
2. Tell it: "Page Performance Attribution"  
3. Add dataset: "events" → "App event logs"
4. Generate → Done ✨

You get a complete pipeline with tests, visualizations, and documentation.

## What You Get

- **Complete project structure** with all the files you need
- **Working code** that's ready to run on your data
- **Tests** to ensure quality
- **Visualizations** to see your results
- **Documentation** so your team understands it

## One More Thing

Check `examples/` for inspiration, or just dive in. The AI figures out the details.