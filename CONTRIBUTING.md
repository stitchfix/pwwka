
## Contributing

We're actively using Pwwka in production here at [Stitch Fix](http://technology.stitchfix.com/) and look forward to seeing Pwwka grow and improve with your help. Contributions are warmly welcomed.

To contribute, 
1. make a fork of the project
2. write some code (with tests please!) 
3. open a Pull Request	
4. bask in the warm fuzzy Open Source hug from us

## Testing
The message_handler gem has tests for all its functionality so app testing is best done with expectations. However, if you want to test the message bus end-to-end in your app you can use some helpers in `lib/stitch_fix/message_handler/test_handler.rb`. See the gem specs for examples of how to use them.