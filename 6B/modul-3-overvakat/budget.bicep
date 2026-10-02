// Budgetlarm för hela prenumerationen. Läggs upp innan något dyrt testas,
// 
targetScope = 'subscription'

@description('Månadsbudget i prenumerationens valuta.')
param belopp int = 100

@description('Vem som får larmen.')
param larmMejl string

@description('Budgetens första månad, måste vara den första i en månad.')
param startDatum string = '2026-10-01'

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'budget-novatrix'
  properties: {
    category: 'Cost'
    amount: belopp
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDatum
    }
    notifications: {
      // Tidig varning när halva budgeten är använd.
      halvvags: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [ larmMejl ]
      }
      narGransen: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 90
        thresholdType: 'Actual'
        contactEmails: [ larmMejl ]
      }
      // Prognosen slår till innan pengarna faktiskt är slut.
      prognosOver: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [ larmMejl ]
      }
    }
  }
}
