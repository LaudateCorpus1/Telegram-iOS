import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import TemporaryCachedPeerDataManager
import AccountContext

public enum ChatMessageEntryContentType {
    case generic
    case largeEmoji
    case animatedEmoji
}

public struct ChatMessageEntryAttributes: Equatable {
    let rank: CachedChannelAdminRank?
    let isContact: Bool
    let contentTypeHint: ChatMessageEntryContentType
    let updatingMedia: ChatUpdatingMessageMedia?
    let isPlaying: Bool
    
    init(rank: CachedChannelAdminRank?, isContact: Bool, contentTypeHint: ChatMessageEntryContentType, updatingMedia: ChatUpdatingMessageMedia?, isPlaying: Bool) {
        self.rank = rank
        self.isContact = isContact
        self.contentTypeHint = contentTypeHint
        self.updatingMedia = updatingMedia
        self.isPlaying = isPlaying
    }
    
    public init() {
        self.rank = nil
        self.isContact = false
        self.contentTypeHint = .generic
        self.updatingMedia = nil
        self.isPlaying = false
    }
}

enum ChatHistoryEntry: Identifiable, Comparable {
    case MessageEntry(Message, ChatPresentationData, Bool, MessageHistoryEntryMonthLocation?, ChatHistoryMessageSelection, ChatMessageEntryAttributes)
    case MessageGroupEntry(MessageGroupInfo, [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes)], ChatPresentationData)
    case UnreadEntry(MessageIndex, ChatPresentationData)
    case ReplyCountEntry(MessageIndex, Bool, Int, ChatPresentationData)
    case ChatInfoEntry(String, String, ChatPresentationData)
    case SearchEntry(PresentationTheme, PresentationStrings)
    
    var stableId: UInt64 {
        switch self {
            case let .MessageEntry(message, _, _, _, _, attributes):
                let type: UInt64
                switch attributes.contentTypeHint {
                    case .generic:
                        type = 2
                    case .largeEmoji:
                        type = 3
                    case .animatedEmoji:
                        type = 4
                }
                return UInt64(message.stableId) | ((type << 40))
            case let .MessageGroupEntry(groupInfo, _, _):
                return UInt64(groupInfo.stableId) | ((UInt64(2) << 40))
            case .UnreadEntry:
                return UInt64(4) << 40
            case .ReplyCountEntry:
                return UInt64(5) << 40
            case .ChatInfoEntry:
                return UInt64(6) << 40
            case .SearchEntry:
                return UInt64(7) << 40
        }
    }
    
    var index: MessageIndex {
        switch self {
            case let .MessageEntry(message, _, _, _, _, _):
                return message.index
            case let .MessageGroupEntry(_, messages, _):
                return messages[messages.count - 1].0.index
            case let .UnreadEntry(index, _):
                return index
            case let .ReplyCountEntry(index, _, _, _):
                return index
            case .ChatInfoEntry:
                return MessageIndex.absoluteLowerBound()
            case .SearchEntry:
                return MessageIndex.absoluteLowerBound()
        }
    }

    static func ==(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
        switch lhs {
            case let .MessageEntry(lhsMessage, lhsPresentationData, lhsRead, _, lhsSelection, lhsAttributes):
                switch rhs {
                    case let .MessageEntry(rhsMessage, rhsPresentationData, rhsRead, _, rhsSelection, rhsAttributes) where lhsMessage.index == rhsMessage.index && lhsMessage.flags == rhsMessage.flags && lhsRead == rhsRead:
                        if lhsPresentationData !== rhsPresentationData {
                            return false
                        }
                        if lhsMessage.stableVersion != rhsMessage.stableVersion {
                            return false
                        }
                        if lhsMessage.media.count != rhsMessage.media.count {
                            return false
                        }
                        for i in 0 ..< lhsMessage.media.count {
                            if !lhsMessage.media[i].isEqual(to: rhsMessage.media[i]) {
                                return false
                            }
                        }
                        if lhsMessage.associatedMessages.count != rhsMessage.associatedMessages.count {
                            return false
                        }
                        if !lhsMessage.associatedMessages.isEmpty {
                            for (id, message) in lhsMessage.associatedMessages {
                                if let otherMessage = rhsMessage.associatedMessages[id] {
                                    if otherMessage.stableVersion != message.stableVersion {
                                        return false
                                    }
                                }
                            }
                        }
                        if lhsSelection != rhsSelection {
                            return false
                        }
                        if lhsAttributes != rhsAttributes {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .MessageGroupEntry(lhsGroupInfo, lhsMessages, lhsPresentationData):
                if case let .MessageGroupEntry(rhsGroupInfo, rhsMessages, rhsPresentationData) = rhs, lhsGroupInfo == rhsGroupInfo, lhsPresentationData === rhsPresentationData, lhsMessages.count == rhsMessages.count {
                    for i in 0 ..< lhsMessages.count {
                        let (lhsMessage, lhsRead, lhsSelection, lhsAttributes) = lhsMessages[i]
                        let (rhsMessage, rhsRead, rhsSelection, rhsAttributes) = rhsMessages[i]
                        
                        if lhsMessage.id != rhsMessage.id {
                            return false
                        }
                        if lhsMessage.timestamp != rhsMessage.timestamp {
                            return false
                        }
                        if lhsMessage.flags != rhsMessage.flags {
                            return false
                        }
                        if lhsRead != rhsRead {
                            return false
                        }
                        if lhsSelection != rhsSelection {
                            return false
                        }
                        if lhsPresentationData !== rhsPresentationData {
                            return false
                        }
                        if lhsMessage.stableVersion != rhsMessage.stableVersion {
                            return false
                        }
                        if lhsMessage.media.count != rhsMessage.media.count {
                            return false
                        }
                        for i in 0 ..< lhsMessage.media.count {
                            if !lhsMessage.media[i].isEqual(to: rhsMessage.media[i]) {
                                return false
                            }
                        }
                        if lhsMessage.associatedMessages.count != rhsMessage.associatedMessages.count {
                            return false
                        }
                        if !lhsMessage.associatedMessages.isEmpty {
                            for (id, message) in lhsMessage.associatedMessages {
                                if let otherMessage = rhsMessage.associatedMessages[id] {
                                    if otherMessage.stableVersion != message.stableVersion {
                                        return false
                                    }
                                }
                            }
                        }
                        if lhsAttributes != rhsAttributes {
                            return false
                        }
                    }
                    
                    return true
                } else {
                    return false
                }
            case let .UnreadEntry(lhsIndex, lhsPresentationData):
                if case let .UnreadEntry(rhsIndex, rhsPresentationData) = rhs, lhsIndex == rhsIndex, lhsPresentationData === rhsPresentationData {
                    return true
                } else {
                    return false
                }
            case let .ReplyCountEntry(lhsIndex, lhsIsComments, lhsCount, lhsPresentationData):
                if case let .ReplyCountEntry(rhsIndex, rhsIsComments, rhsCount, rhsPresentationData) = rhs, lhsIndex == rhsIndex, lhsIsComments == rhsIsComments, lhsCount == rhsCount, lhsPresentationData === rhsPresentationData {
                    return true
                } else {
                    return false
                }
            case let .ChatInfoEntry(lhsTitle, lhsText, lhsPresentationData):
                if case let .ChatInfoEntry(rhsTitle, rhsText, rhsPresentationData) = rhs, lhsTitle == rhsTitle, lhsText == rhsText, lhsPresentationData === rhsPresentationData {
                    return true
                } else {
                    return false
                }
            case let .SearchEntry(lhsTheme, lhsStrings):
                if case let .SearchEntry(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
        let lhsIndex = lhs.index
        let rhsIndex = rhs.index
        if lhsIndex == rhsIndex {
            return lhs.stableId < rhs.stableId
        } else {
            return lhsIndex < rhsIndex
        }
    }
}
