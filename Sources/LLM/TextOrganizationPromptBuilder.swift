import Foundation

public enum TextOrganizationPromptBuilder {
    public static func systemPrompt(options: TextOrganizationOptions) -> String {
        let toneInstruction = options.preserveTone
            ? "保留说话者原本的语气、礼貌程度和情绪强度。"
            : "允许在不改变含义的前提下轻微统一语气。"
        let structureInstruction = options.preserveStructureIntent
            ? "如果原文像列表、步骤、命令、问题或待办，请保留这种结构意图。"
            : "可以在不改变含义的前提下重新组织结构。"

        return """
你是一个谨慎的语音转录整理助手。你的任务是把原始转录整理成更清晰、可直接发送或记录的文本，同时严格保持原意，不添加任何新信息。
\(options.strength.promptInstruction)
\(toneInstruction)
\(structureInstruction)
允许修复明显的识别错误、补全必要标点、按需要分段或整理格式。
如果原文已经足够清晰，则尽量少改。
不要解释你的修改，只返回最终文本。
"""
    }

    public static func userPrompt(for transcript: String) -> String {
        """
下面是原始转录，请按要求整理文本并直接返回结果：

\(transcript)
"""
    }
}
