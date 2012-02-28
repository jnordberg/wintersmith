title: Code and stuff!
author: The Wintersmith
date: 2011-10-01 15:00
template: article.jade

Syntax highlighting with highlight.js

### JavaScript

```javascript
function factorial(n) {
  if (n === 0) {
    return 1;
  }
  return n * factorial(n - 1);
}
```

## More samples


Taken from [wikipedia](https://en.wikipedia.org/wiki/Hello_world_program_examples).

### C

```c
#include <stdio.h>

int main(void)
{
  printf("Hello world\n");
  return 0;
}
```

### C++

```cpp
#include <iostream>

int main()
{
  std::cout << "Hello World!" << std::endl;
  return 0;
}
```

### C-sharp

```csharp
class ExampleClass
{
    static void Main()
    {
        System.Console.WriteLine("Hello, world!");
    }
}
```

### COBOL

```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HELLO-WORLD.
       PROCEDURE DIVISION.
           DISPLAY 'Hello, world'.
           STOP RUN.
```

### Erlang

```erlang
io:format("~s~n", ["hello, world"])
```

### Go

```go
package main

import "fmt"

func main() {
   fmt.Println("Hello World!")
}
```

### Java

```java
public class HelloWorld {
   public static void main(String[] args) {
       System.out.println("Hello world!");
   }
}
```

### ObjectiveC

```objc
#import <stdio.h>

int main(void)
{
    printf("Hello, World!\n");
    return 0;
}
```

### PHP

```php
<?php echo 'Hello, world'; ?>
```

### Python

```python
print("Hello World")
```

### Ruby

```ruby
puts "Hello world!"
```





