```
,adPPYba,  8b,dPPYba,    ,adPPYba,  8b,     ,d8  
I8[    ""  88P'    "8a  a8P_____88   `Y8, ,8P'   
 `"Y8ba,   88       d8  8PP"""""""     )888(     
aa    ]8I  88b,   ,a8"  "8b,   ,aa   ,d8" "8b,   
`"YbbdP"'  88`YbbdP"'    `"Ybbd8"'  8P'     `Y8  
           88                                      
           88    
```

👋 Welcome to Spex!

Your AI-powered data pipeline generator
 
**Write a 5-line spec. Get a complete data pipeline.**

Spex uses AI to generate production-ready PySpark/Python/SQL pipelines from simple specifications. No more boilerplate. No more setup hassle. Just describe what you want.

## Install (30 seconds)

## API Key

[An OpenAI API Key](https://openai.com/api/) and/or [Gemini API Key](https://ai.google.dev/gemini-api/docs)

Copy the example `.env` file and add your OpenAI API key.

Run this:
```bash
cp .env.example .env
# Edit .env and add your key:
# OPENAI_API_KEY="sk-..."
# GEMINI_API_KEY="AI..."
```

## Install
```bash
git clone git@github.com:renbytes/spex.git
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
2. Explain the analysis: `Page Performance Attribution`
3. Add dataset: `database.event_logs`
4. Add description: `App event logs`
4. Generate → Done ✨

You get a complete pipeline with tests, visualizations, and documentation.

## What You Get

- **Complete project structure** with all the files you need
- **Working code** that's ready to run on your data
- **Tests** to ensure quality
- **Visualizations** to see your results
- **Documentation** so your team understands it

## Examples

Explore real-world use cases in the `examples/` directory:

- **[E-commerce](examples/ecommerce/)** - Top selling products analysis (SQL)
- **[Healthcare](examples/healthcare/)** - Patient length of stay analysis (SQL)
- **[Finance](examples/finance/)** - Stock volatility calculation (Python)
- **[Energy](examples/energy/)** - Renewable energy production analysis (Python)
- **[Consumer Tech](examples/consumer_tech/)** - Ad attribution pipeline (PySpark)

## Supported Languages

| Language | Framework | Use Case |
|----------|-----------|----------|
| **Python** | pandas | Data analysis, reporting |
| **PySpark** | Spark | Big data, distributed computing |
| **SQL** | dbt-style | Data warehousing, analytics |

## Development

### Running Checks

To ensure code quality, run the following commands:

**Format**

Run:
```bash
swift-format -i -r Sources/ Tests/
```

> Note: you will need to install `swift-lint` if you don't already have it. Run `brew install swift-format`.

**Test**

Run:
```bash
swift test
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

- 📖 **Documentation:** Check the [/docs](docs/)
- 🐛 **Issues:** Report bugs on [GitHub Issues](https://github.com/renbytes/spex/issues)
