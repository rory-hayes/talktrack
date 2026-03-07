export const interviewPrompts = [
  "Tell me about yourself",
  "Walk me through your resume",
  "Why do you want this role",
  "Why do you want to work here",
  "Tell me about a project you're proud of",
  "Tell me about a challenge you faced",
  "Tell me about a failure",
  "Tell me about a time you solved a difficult problem",
  "Tell me about a time you worked in a team",
  "Tell me about a disagreement with a coworker",
  "Tell me about a time you handled conflict",
  "Tell me about a time you had to learn something quickly",
  "Tell me about a time you met a tight deadline",
  "Tell me about a time you improved a process",
  "Tell me about a time you took initiative",
  "Tell me about a time you led something",
  "Tell me about a time you handled feedback",
  "Tell me about a time you made a mistake",
  "Tell me about a time you helped a teammate",
  "Describe your biggest professional achievement",
  "What are your strengths",
  "What are your weaknesses",
  "Where do you want to be in five years",
  "Why should we hire you",
  "Describe your work style",
  "How do you handle pressure",
  "How do you prioritize work",
  "Describe a time you solved a customer problem",
  "Describe a time you had multiple deadlines",
  "Describe a time you adapted to change",
  "Describe a time you disagreed with a decision",
  "Describe a time you improved efficiency",
  "Describe a time you handled ambiguity",
  "Describe a time you learned from failure",
  "Describe a time you delivered results",
  "Describe a time you handled a difficult stakeholder",
  "Describe a time you had to persuade someone",
  "Describe a time you handled criticism",
  "Describe a time you exceeded expectations",
  "Describe a time you fixed a broken process",
  "Describe a time you worked cross-functionally",
  "Describe a time you handled responsibility",
  "Describe a time you worked independently",
  "Describe a time you managed your time well",
  "Describe a time you helped improve a team",
  "Describe a time you faced uncertainty",
  "Describe a time you handled pressure",
  "Describe a time you went beyond your role",
  "Describe a time you solved something creatively",
  "Describe a time you handled a difficult situation"
];

export const workplacePrompts = [
  "Give a quick standup update",
  "Explain what you worked on yesterday",
  "Explain what you're working on today",
  "Explain a blocker to your manager",
  "Summarize a meeting outcome",
  "Explain the status of a project",
  "Explain why a deadline moved",
  "Explain progress on a feature",
  "Explain an issue you're investigating",
  "Explain a bug to your team",
  "Explain a solution you propose",
  "Explain a decision you made",
  "Explain why something failed",
  "Explain a change in priorities",
  "Explain the next steps of a project",
  "Explain a product feature",
  "Explain a concept to a non-technical colleague",
  "Explain a delay to a stakeholder",
  "Explain a project outcome",
  "Explain the key takeaway from a report",
  "Answer a question from your manager",
  "Answer why a project is delayed",
  "Answer why an approach changed",
  "Answer a question about your analysis",
  "Answer a question about your results",
  "Push back on an unrealistic deadline",
  "Push back on a request politely",
  "Suggest a better approach",
  "Propose an idea to your team",
  "Recommend a decision",
  "Ask your manager for clarification",
  "Ask for help on a blocker",
  "Ask for additional resources",
  "Ask a teammate for support",
  "Give constructive feedback to a colleague",
  "Explain a mistake to your manager",
  "Explain what you learned from a mistake",
  "Explain a difficult problem you solved",
  "Walk a stakeholder through a proposal",
  "Present a quick project summary",
  "Explain key metrics to leadership",
  "Explain an improvement idea",
  "Respond to a challenge to your idea",
  "Respond to criticism of your work",
  "Respond when someone disagrees with you",
  "Explain your reasoning behind a decision",
  "Explain why something is important",
  "Clarify a misunderstanding",
  "Correct incorrect information politely",
  "Explain an idea quickly in 30 seconds",
  "Explain a complex topic simply",
  "Give a quick recommendation",
  "Summarize three options",
  "Explain risks in a project",
  "Explain tradeoffs in a decision",
  "Give next steps after a meeting",
  "Explain what success looks like",
  "Explain how you prioritized work",
  "Explain how you solved a difficult issue",
  "Give a status update to leadership in one minute",
  "Present a proposal with one clear recommendation",
  "Handle a meeting interruption professionally",
  "Explain a scope change to your team",
  "Respond to an unexpected question in a meeting",
  "Escalate a risk to your manager",
  "Request timeline relief with clear rationale",
  "Align two teams on a shared next step",
  "Summarize action items at meeting close",
  "Explain why a tradeoff was necessary",
  "Share a progress update with limited data",
  "State a disagreement respectfully in a meeting",
  "Ask a clarifying follow-up question",
  "Explain a technical dependency to product",
  "Explain why quality checks are needed",
  "Ask for feedback after presenting work",
  "Set expectations for an uncertain timeline",
  "Deliver a concise risk-benefit summary",
  "Respond to a missed deadline update",
  "Explain what changed after new requirements",
  "Recap a decision and owner assignments"
];

export const customerPrompts = [
  "Explain your product to a customer",
  "Explain a feature to a new user",
  "Respond to a customer complaint",
  "Explain how a solution works",
  "Explain the benefits of a product",
  "Explain pricing clearly",
  "Clarify a misunderstanding",
  "Respond to a customer objection",
  "Walk a customer through a solution",
  "Explain why something cannot be done",
  "Explain alternatives to a customer",
  "Explain a delay to a client",
  "Explain next steps to a client",
  "Explain the outcome of a support ticket",
  "Summarize a client meeting",
  "Explain how to get started",
  "Explain how to solve a problem",
  "Explain the value of your solution",
  "Handle a skeptical customer question",
  "Respond to a request for clarification",
  "Explain a technical concept simply",
  "Explain a feature limitation",
  "Explain a roadmap item",
  "Explain a change to a customer",
  "Explain a fix to a problem",
  "Explain a process step",
  "Explain how to troubleshoot something",
  "Guide a customer through an issue",
  "Explain what happens next",
  "Explain how long something will take",
  "Explain the outcome of an investigation",
  "Explain a recommended solution",
  "Explain why a feature matters",
  "Explain the results of a change",
  "Explain how to measure success",
  "Explain how to use a tool",
  "Explain how to configure something",
  "Explain the best next step",
  "Explain what to expect",
  "Summarize support options for a customer"
];

function difficultyForIndex(index) {
  if (index < 20) {
    return "easy";
  }
  if (index < 45) {
    return "medium";
  }
  return "hard";
}

function tagsForPrompt(prompt, mode) {
  const base = [mode, "work-communication"];
  const lowered = prompt.toLowerCase();

  if (lowered.includes("stakeholder") || lowered.includes("customer") || lowered.includes("client")) {
    base.push("stakeholder");
  }
  if (lowered.includes("delay") || lowered.includes("deadline") || lowered.includes("risk")) {
    base.push("risk-management");
  }
  if (lowered.includes("explain")) {
    base.push("clarity");
  }
  if (lowered.includes("summarize") || lowered.includes("quick") || lowered.includes("concise")) {
    base.push("conciseness");
  }

  return [...new Set(base)];
}

function scenariosForMode(mode, prompts) {
  return prompts.map((prompt, index) => ({
    id: `${mode}_${String(index + 1).padStart(3, "0")}`,
    mode,
    promptText: prompt,
    tags: tagsForPrompt(prompt, mode),
    difficulty: difficultyForIndex(index),
    active: true,
    createdAt: new Date().toISOString(),
  }));
}

export function buildScenarioLibrary() {
  if (interviewPrompts.length !== 50) {
    throw new Error(`Interview prompt count must be 50, received ${interviewPrompts.length}`);
  }
  if (workplacePrompts.length !== 80) {
    throw new Error(`Workplace prompt count must be 80, received ${workplacePrompts.length}`);
  }
  if (customerPrompts.length !== 40) {
    throw new Error(`Customer prompt count must be 40, received ${customerPrompts.length}`);
  }

  return [
    ...scenariosForMode("interview", interviewPrompts),
    ...scenariosForMode("workplace", workplacePrompts),
    ...scenariosForMode("customer", customerPrompts),
  ];
}
