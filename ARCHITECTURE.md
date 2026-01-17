# AnalyzerDPS - Web Integration Architecture (Future Implementation)

## Overview
This document outlines the planned architecture for web integration features including error reporting and analysis sharing.

## Phase 1: Error Reporting System

### Backend Requirements
- **Endpoint**: `POST /api/v1/errors`
- **Technology Stack**: Node.js/Express or Python/Flask
- **Database**: PostgreSQL or MongoDB
- **Hosting**: Heroku, DigitalOcean, or AWS Lambda

### Data Structure
```json
{
  "addon_version": "0.74",
  "game_version": "5.5.3",
  "player": {
    "class": "MAGE",
    "spec": "Frost",
    "realm": "string",
    "name": "string"
  },
  "error": {
    "message": "string",
    "stack_trace": "string",
    "timestamp": "ISO8601",
    "context": {}
  },
  "system_info": {
    "locale": "plPL",
    "fps": 60,
    "latency": 50
  }
}
```

### Lua Implementation
```lua
function Analyzer:ReportError(errorMsg, context)
  local payload = {
    addon_version = self.VERSION,
    game_version = "5.5.3",
    player = {
      class = self.player.class,
      spec = self.player.specName,
      realm = GetRealmName(),
      name = UnitName("player")
    },
    error = {
      message = errorMsg,
      timestamp = date("%Y-%m-%dT%H:%M:%S"),
      context = context or {}
    }
  }
  
  -- Send via HTTP (requires external library or web request addon)
  -- Implementation pending WoW API limitations
end
```

## Phase 2: Analysis Sharing System

### Backend Requirements
- **Endpoint**: `POST /api/v1/reports`
- **Endpoint**: `GET /api/v1/reports/:id`
- **Storage**: S3 or similar for JSON blobs
- **CDN**: CloudFlare for static assets

### Report Data Structure
```json
{
  "id": "uuid",
  "created_at": "ISO8601",
  "player": {
    "class": "MAGE",
    "spec": "Frost",
    "name": "string",
    "realm": "string"
  },
  "fight": {
    "duration": 180.5,
    "boss": "Horridon",
    "difficulty": "Heroic",
    "score": 87,
    "dps": 125000
  },
  "metrics": [],
  "issues": [],
  "timeline": [],
  "spells": {}
}
```

### Web Viewer Features
- Interactive timeline visualization (D3.js or Chart.js)
- Spell breakdown with icons
- Comparison with other players
- Rotation replay
- Export to image/PDF

### URL Structure
- `https://analyzerdps.com/report/{uuid}`
- `https://analyzerdps.com/compare/{uuid1}/{uuid2}`
- `https://analyzerdps.com/player/{realm}/{name}`

## Phase 3: Community Features

### Planned Features
1. **Leaderboards**: Top scores per boss/spec
2. **Guild Analytics**: Aggregate guild performance
3. **Rotation Library**: Community-submitted optimal rotations
4. **Boss Guides**: Integrated with analysis data

## Security Considerations

### API Authentication
- API keys for addon requests
- Rate limiting (100 requests/hour per player)
- CAPTCHA for web submissions

### Data Privacy
- Anonymous mode option
- GDPR compliance
- Data retention policy (90 days)
- Player name hashing option

## Implementation Timeline

### Q1 2026
- [ ] Set up basic backend infrastructure
- [ ] Implement error reporting endpoint
- [ ] Add error reporting UI in addon

### Q2 2026
- [ ] Implement report sharing endpoint
- [ ] Create basic web viewer
- [ ] Add "Share Report" button in addon

### Q3 2026
- [ ] Add interactive timeline
- [ ] Implement comparison features
- [ ] Launch beta testing

### Q4 2026
- [ ] Community features
- [ ] Mobile-responsive design
- [ ] Performance optimization

## Technical Challenges

### WoW API Limitations
- No native HTTP requests in WoW Lua
- Workarounds:
  1. Use external addon like `WeakAuras` with custom code
  2. Clipboard export → manual paste to website
  3. Saved variables → external tool reads and uploads

### Recommended Approach (Phase 1)
1. Export report to clipboard as JSON
2. User pastes to website
3. Website generates shareable link
4. Future: Investigate HTTP libraries

## Cost Estimation

### Monthly Operating Costs
- **Hosting**: $20-50 (DigitalOcean/Heroku)
- **Database**: $15-30 (managed PostgreSQL)
- **CDN**: $10-20 (CloudFlare)
- **Storage**: $5-10 (S3)
- **Total**: ~$50-110/month

### Scaling Considerations
- Serverless functions for cost efficiency
- Caching layer (Redis) for popular reports
- Database indexing on player/boss/date

## Notes
This architecture is designed to be implemented incrementally. The addon will continue to function fully offline, with web features as optional enhancements.
