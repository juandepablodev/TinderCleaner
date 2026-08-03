import Foundation

/// Represents a classification decision made on a photo or video card.
public enum SwipeDecision: Sendable, Equatable {
  case keep
  case delete
}
