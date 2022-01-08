## Takeover 

A contract for placing a takeover bid for an NFT collection. The bidder must lock funds in the takeover contract, and specifity a bid expiration and success threshold. 

Owners of the NFT then have the option to lock their tokens in the takeover contract, and receive a "wrapped" token in return. If the number of locked tokens is above the success threshold by the bid expiration, the takeover is considered successful. At this point, all tokens are permanently locked, and the bid is distributed among wrapped NFT holders, proportionally to how early they wrapped their tokens. 

If the threshold is not met by expiration, the takeover is considered a failure. Wrapped token holders are free to unwrap their tokens are receive the original back. The bidder can also withdraw their bid freely. 

Note that the bidder can add arbitrariy logic into the takeover contract, meaning that takeover attempts can act similarly to governance proposals, with the community deciding to accept by locking their tokens. 
