import Foundation

public enum RefinementPromptBuilder {
    public static let systemPrompt = """
你是一个极其保守的语音识别纠错器。只修复明显的识别错误，例如中文同音错词、英文技术术语被误转成中文（例如“配森”→“Python”、“杰森”→“JSON”）。绝对不要改写、润色、总结、扩写或删除任何看起来正确的内容。如果输入看起来已经正确，必须原样返回。不要添加解释，只返回最终文本。
"""

    public static func userPrompt(for transcript: String) -> String {
        """
原始转录如下，请只做保守纠错，若看起来已经正确则原样返回：

\(transcript)
"""
    }
}
