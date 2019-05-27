import { Grommet } from 'grommet';
import * as React from 'react';

const customTheme = {
  button: {
    border: {
      radius: "4px"
    },
    color: "white",
  },
  global: {
    colors: {
      brand: "#4ec995",
      text: "black",
      border: "black"
    },
  },
  checkBox: {
    border: {
      color: {
        light: "#4ec995"
      },
      radius: "2px"
    },
    color: {
      light: "#4ec995"
    },
    hover: {
      border: {
        color: "undefined",
      }
    },
    extend: `
      color: black;
    `
  }
}

export default ({ children }: { children?: React.ReactNode }) => {
  return (
    <Grommet theme={customTheme}>{children}</Grommet>
  )
}
