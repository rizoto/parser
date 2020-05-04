import Foundation

struct Pricing: Decodable {
    let time: String
    let prices: Array<Price>
    struct Price: Decodable {
        let type: String
        let time: String
        let bids:Array<BidAsk>
        let asks:Array<BidAsk>
        struct BidAsk: Decodable {
            let price: String
            let liquidity: Int
        }
        let closeoutBid: String
        let closeoutAsk: String
        let status: String
        let tradeable: Bool
        let unitsAvailable: AvailableUnits?
        struct AvailableUnits: Decodable {
            let `default`: LongShort
            struct LongShort: Decodable {
                let long: String
                let short: String
            }
            let openOnly: LongShort
            let reduceFirst: LongShort
            let reduceOnly: LongShort
        }
        let quoteHomeConversionFactors: QuoteHomeConversionFactors?
        struct QuoteHomeConversionFactors: Decodable {
            let positiveUnits: String
            let negativeUnits: String
        }
        let instrument: String
    }
}
extension Pricing {
    var eur_usd: Price {
        return self.prices.filter({ (p) -> Bool in
            return p.instrument == "EUR_USD"
        })[0]
    }
    
    var aud_usd: Price {
        return self.prices.filter({ (p) -> Bool in
            return p.instrument == "AUD_USD"
        })[0]
    }
}
