# Substitutions and consistency

Modal ladder, slop → plain table, and the one-word-one-meaning consistency sets. Adapted from [SimpleEnglish](https://github.com/AminBlg/SimpleEnglish) (MIT).

## Modal ladder

Approved modals: `can`, `will`, `must`. Weak modals blur whether something is required or optional — models read "should" as optional.

| You wrote | Write instead |
|---|---|
| should (requirement) | must |
| should (recommendation) | delete it, or state it as fact: "X is better because Y." |
| may / might / could (possibility) | can |
| may (permission) | can |
| would (hypothetical) | restructure: "If X occurs, Y occurs." |

STE rejects "could" even for possibility: write "an explosion can occur", never "could occur".

## Slop → plain

Maps the words AI-generated docs overuse to plain replacements. If the word carries no fact, delete it instead of replacing it.

| Slop | Write instead |
|---|---|
| leverage, utilize | use |
| in order to | to |
| prior to | before |
| ensure | make sure that |
| it is worth noting that | (delete) |
| it's important to, crucially | (delete — state the fact) |
| simply, just, easily, seamlessly, effortlessly | (delete) |
| robust, powerful, comprehensive, performant | (delete, or give the measurable property) |
| functionality | function, feature |
| enables you to, allows you to | you can |
| is designed to, aims to | (delete — say what it does) |
| facilitate | help, make possible |
| dive into, delve into | read, examine |
| when it comes to | for |
| in the event that | if |
| due to the fact that | because |
| as needed, as necessary | (state the condition) |
| and/or | pick one, or write "X, or Y, or both" |
| e.g. / i.e. / etc. | for example / that is / (name the items) |
| gracefully handles | (say what it does: "retries three times, then stops") |
| out of the box | by default |
| under the hood | internally |
| blazingly fast, state-of-the-art | fast (give the number) / (delete) |
| streamline | make simpler, make faster |
| plethora, myriad | many |
| addresses the issue, tackles | corrects the fault, removes the error |

## One word, one meaning

Pick one term per concept and hold it across the whole document. Collapse these common rotations:

- check / verify / confirm / validate / ensure → pick one
- config / configuration / settings / options → pick one
- delete / remove / drop / destroy → one per meaning, kept consistent
- error / issue / problem / failure → "error" for errors, "failure" for failed operations
- run / execute / invoke / launch → pick one
- show / display / render / present → pick one

## Known part-of-speech rulings

Useful as patterns (from STE's dictionary mechanics):

| Word | Ruling |
|---|---|
| test, check, work | Noun only. "Do a test", not "test the pump". "Check that X" → "make sure that X". |
| help | Verb only. For the noun, use "aid": "with the aid of". |
| follow | "To come after" only, never "obey". Write "obey the instructions". |
| above, below | Physical positions only. For limits write "more than", "less than". |

## Phrasal verbs and Latin

- Do not build phrasal verbs: "go down" → "decrease", "set up" → "install" or "configure".
- "e.g." → "for example", "i.e." → "that is", delete "etc." — name the items or write "and more".
